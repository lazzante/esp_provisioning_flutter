// ProvisioningBridge.swift
//
// Isolates every interaction with Espressif's ESPProvision SDK from the
// Flutter plugin entry point. The plugin class translates method-channel
// invocations into Bridge calls; the Bridge owns the SDK-side state machine,
// emits lifecycle events through the supplied EventEmitter, and translates
// the SDK's error vocabulary into the typed FlutterError codes that the Dart
// side's `mapPlatformException` knows how to dispatch on.
//
// Threading: every public method on Bridge is expected to be called from the
// Flutter UI thread (the method channel is bound there). All Result and
// Event emissions are themselves dispatched to the main queue, since
// ESPProvision callbacks can land on arbitrary queues.

import CoreBluetooth
import ESPProvision
import Flutter
import Foundation

/// Receives lifecycle events from the bridge. Implemented by the plugin
/// class so the bridge stays decoupled from the FlutterEventChannel itself
/// (and so a fake can be substituted in unit tests).
protocol EspEventEmitter: AnyObject {
    func emit(_ event: [String: Any?])
}

/// The username ESP-IDF stamps into security2-enabled firmware by default.
/// Production fleets may override this via firmware; we expose no
/// per-device override because every device we ship uses the default. If
/// that changes, plumb a `username` parameter through to `connect`.
private let kDefaultSecurity2Username = "wifiprov"

/// Wraps ESPProvision's stateful, callback-driven API behind a single
/// per-plugin actor. Holds the discovered device cache, the currently
/// connected device, and the in-flight scan state. Not thread-safe on its
/// own — relies on being called only from the main queue.
final class ProvisioningBridge {

    // MARK: - State

    private weak var eventEmitter: EspEventEmitter?

    /// Last successful scan's results, keyed by `ESPDevice.name`. ESPDevice
    /// instances must be retained between `scanBleDevices` and `connect`,
    /// otherwise the SDK can't re-use the BLE transport that found them.
    private var discoveredDevices: [String: ESPDevice] = [:]

    /// The currently-connected device. Held strong while a session is open
    /// so that ESPProvision's internal queues retain access to it; released
    /// on `disconnect` to avoid retain cycles via the SRP / security layers.
    private var connectedDevice: ESPDevice?

    /// Security level used for the active connection — needed when mapping
    /// `ESPSessionError.sessionInitError` back to a typed Dart exception
    /// (the same SDK error means "wrong PoP" under sec1/sec2 but a generic
    /// handshake failure under sec0).
    private var activeSecurity: ESPSecurity = .secure2

    /// Strong references to per-connection PoP delegates. The SDK holds the
    /// delegate weakly during `connect`; without this we'd lose the closure
    /// before the SDK calls back.
    private var popDelegateRefs: [ObjectIdentifier: PopDelegate] = [:]

    // Concurrency guards.
    private var scanInFlight = false
    private var connectInFlight = false
    private var scanTimer: Timer?
    private var scanResult: FlutterResult?

    // Bluetooth state probe — created lazily, kept alive for the lifetime
    // of the bridge so the iOS Core Bluetooth runtime sees a stable owner.
    private lazy var btProbe = BluetoothStateProbe()

    init(eventEmitter: EspEventEmitter) {
        self.eventEmitter = eventEmitter
    }

    // MARK: - Method channel entry points

    func scanBleDevices(
        devicePrefix: String,
        timeoutMs: Int,
        result: @escaping FlutterResult
    ) {
        // Cancel any previous in-flight scan.
        if scanInFlight {
            ESPProvisionManager.shared.stopESPDevicesSearch()
            stopScanTimer()
            // The previous caller waits for an empty result rather than an
            // exception — superseding scans is a normal UI pattern.
            scanResult?([])
            scanResult = nil
            scanInFlight = false
            emit(phase: "scanFinished", message: "superseded by new scan")
        }

        btProbe.checkAvailability { [weak self] availability in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch availability {
                case .available:
                    self.startBleScan(devicePrefix: devicePrefix,
                                      timeoutMs: timeoutMs,
                                      result: result)
                case .poweredOff:
                    result(FlutterError(
                        code: "ble_unavailable",
                        message: "Bluetooth is powered off or unsupported on this device",
                        details: nil))
                case .unauthorized:
                    result(FlutterError(
                        code: "permission_denied",
                        message: "App is not authorised to use Bluetooth",
                        details: ["permission": "bluetooth"]))
                }
            }
        }
    }

    func stopBleScan(result: @escaping FlutterResult) {
        if scanInFlight {
            ESPProvisionManager.shared.stopESPDevicesSearch()
            stopScanTimer()
            scanResult?([])
            scanResult = nil
            scanInFlight = false
            emit(phase: "scanFinished", message: "stopped by caller")
        }
        result(nil)
    }

    func connect(
        deviceMap: [String: Any?],
        proofOfPossession: String,
        security: Int,
        result: @escaping FlutterResult
    ) {
        if connectInFlight || connectedDevice != nil {
            result(FlutterError(
                code: "session_failed",
                message: "A connection is already in flight or established; call disconnect() first",
                details: nil))
            return
        }

        guard let deviceId = deviceMap["id"] as? String, !deviceId.isEmpty else {
            result(FlutterError(
                code: "session_failed",
                message: "connect: device map missing valid 'id'",
                details: nil))
            return
        }

        guard let device = discoveredDevices[deviceId] else {
            result(FlutterError(
                code: "device_not_found",
                message: "Device '\(deviceId)' is no longer in the scan cache. Re-scan and try again.",
                details: ["deviceId": deviceId]))
            return
        }

        let espSecurity = ESPSecurity(rawValue: security)
        device.security = espSecurity
        // `proofOfPossession` is `internal` on ESPDevice — we cannot set it
        // directly. The PopDelegate below supplies it through the public
        // delegate callback that ESPDevice.initialiseSession invokes when
        // its own `proofOfPossession` slot is nil (which it always is for
        // devices freshly discovered by `searchESPDevices`).
        if espSecurity == .secure2 {
            device.username = kDefaultSecurity2Username
        }
        activeSecurity = espSecurity
        connectInFlight = true

        let popDelegate = PopDelegate(pop: proofOfPossession,
                                      username: kDefaultSecurity2Username)
        let popKey = ObjectIdentifier(popDelegate)
        popDelegateRefs[popKey] = popDelegate

        emit(phase: "connecting", deviceId: deviceId)

        device.connect(delegate: popDelegate) { [weak self] status in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.popDelegateRefs.removeValue(forKey: popKey)
                self.connectInFlight = false
                switch status {
                case .connected:
                    self.connectedDevice = device
                    self.emit(phase: "sessionEstablished", deviceId: deviceId)
                    result(nil)
                case .failedToConnect(let error):
                    self.emit(phase: "disconnected",
                              deviceId: deviceId,
                              message: error.description)
                    result(ErrorMapping.flutterError(
                        forSessionError: error,
                        security: self.activeSecurity,
                        ssidOrName: deviceId))
                case .disconnected:
                    self.emit(phase: "disconnected", deviceId: deviceId)
                    result(FlutterError(
                        code: "session_failed",
                        message: "Connection terminated before session established",
                        details: nil))
                }
            }
        }

        emit(phase: "sessionEstablishing", deviceId: deviceId)
    }

    func scanWifiNetworks(result: @escaping FlutterResult) {
        guard let device = connectedDevice else {
            result(FlutterError(
                code: "session_failed",
                message: "No active session. Call connect() first.",
                details: nil))
            return
        }
        emit(phase: "wifiScanning", deviceId: device.name)
        device.scanWifiList { [weak self] networks, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    result(ErrorMapping.flutterError(forWifiScanError: error))
                    return
                }
                let payload = (networks ?? []).map(self.encode(network:))
                result(payload)
            }
        }
    }

    func provisionWifi(ssid: String, passphrase: String, result: @escaping FlutterResult) {
        guard let device = connectedDevice else {
            result(FlutterError(
                code: "session_failed",
                message: "No active session. Call connect() first.",
                details: nil))
            return
        }
        emit(phase: "applyingCredentials", deviceId: device.name)
        device.provision(ssid: ssid, passPhrase: passphrase) { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch status {
                case .success:
                    let r: [String: Any?] = ["status": "success"]
                    self.emit(phase: "finished", deviceId: device.name, result: r)
                    result(r)
                case .configApplied:
                    // Interim phase — ESPProvision will follow up with
                    // .success or .failure. Treat as a progress event;
                    // do NOT resolve the Dart future here.
                    self.emit(phase: "applyingCredentials",
                              deviceId: device.name,
                              message: "configApplied")
                case .failure(let error):
                    if case .wifiStatusDisconnected = error {
                        // Transport-level breakdown: surfaces as an
                        // exception, not an in-band result, per the
                        // sealed-exception contract.
                        result(FlutterError(
                            code: "wifi_provisioning_failed",
                            message: error.description,
                            details: nil))
                        self.emit(phase: "disconnected",
                                  deviceId: device.name,
                                  message: error.description)
                        return
                    }
                    let r = ErrorMapping.provisioningResultMap(for: error)
                    self.emit(phase: "finished", deviceId: device.name, result: r)
                    result(r)
                }
            }
        }
    }

    func sendCustomData(endpoint: String, data: FlutterStandardTypedData, result: @escaping FlutterResult) {
        guard let device = connectedDevice else {
            result(FlutterError(
                code: "session_failed",
                message: "No active session. Call connect() first.",
                details: nil))
            return
        }
        device.sendData(path: endpoint, data: data.data) { response, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(ErrorMapping.flutterError(
                        forSessionError: error,
                        security: self.activeSecurity,
                        ssidOrName: device.name))
                    return
                }
                result(FlutterStandardTypedData(bytes: response ?? Data()))
            }
        }
    }

    func disconnect(result: @escaping FlutterResult) {
        if let device = connectedDevice {
            device.disconnect()
            emit(phase: "disconnected", deviceId: device.name)
        }
        connectedDevice = nil
        result(nil)
    }

    // MARK: - Internals

    private func startBleScan(
        devicePrefix: String,
        timeoutMs: Int,
        result: @escaping FlutterResult
    ) {
        scanInFlight = true
        scanResult = result
        emit(phase: "scanStarted")
        ESPProvisionManager.shared.searchESPDevices(
            devicePrefix: devicePrefix,
            transport: .ble,
            security: .secure2
        ) { [weak self] devices, error in
            DispatchQueue.main.async {
                self?.handleScanCompletion(devices: devices, error: error)
            }
        }
        // ESPProvisionManager's internal scan timer is hardcoded to 5s. We
        // install our own as a fallback in case the SDK's callback never
        // fires (observed once on iOS 17 simulator BLE stack stalls).
        installScanTimer(timeoutMs: timeoutMs)
    }

    private func installScanTimer(timeoutMs: Int) {
        scanTimer?.invalidate()
        let interval = max(0.5, Double(timeoutMs) / 1000.0)
        scanTimer = Timer.scheduledTimer(withTimeInterval: interval,
                                         repeats: false) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard self.scanInFlight else { return }
                ESPProvisionManager.shared.stopESPDevicesSearch()
                self.emit(phase: "scanFinished", message: "timeout")
                self.scanResult?(FlutterError(
                    code: "device_not_found",
                    message: "BLE scan timed out after \(timeoutMs) ms",
                    details: ["deviceId": ""]))
                self.scanResult = nil
                self.scanInFlight = false
            }
        }
    }

    private func stopScanTimer() {
        scanTimer?.invalidate()
        scanTimer = nil
    }

    private func handleScanCompletion(devices: [ESPDevice]?, error: ESPDeviceCSSError?) {
        guard scanInFlight else { return }
        stopScanTimer()
        scanInFlight = false
        emit(phase: "scanFinished")

        if let error = error {
            switch error {
            case .espDeviceNotFound:
                // No devices found in scan window — return empty list
                // rather than throwing, since this is a routine UI state.
                discoveredDevices = [:]
                scanResult?([])
            default:
                scanResult?(FlutterError(
                    code: "session_failed",
                    message: error.description,
                    details: nil))
            }
            scanResult = nil
            return
        }

        let list = devices ?? []
        discoveredDevices = Dictionary(uniqueKeysWithValues:
            list.map { (key: $0.name, value: $0) })
        scanResult?(list.map(encode(device:)))
        scanResult = nil
    }

    private func encode(device: ESPDevice) -> [String: Any?] {
        return [
            "id": device.name,
            "name": device.name,
            "transport": "ble",
            "rssi": nil,
            "serviceUuid": nil,
            "bssid": nil,
        ]
    }

    private func encode(network: ESPWifiNetwork) -> [String: Any?] {
        let bssidString: String? = network.bssid.isEmpty
            ? nil
            : network.bssid.map { String(format: "%02x", $0) }.joined(separator: ":")
        let authValue: Int
        switch network.auth {
        case .open: authValue = 0
        case .wep: authValue = 1
        case .wpaPsk: authValue = 2
        case .wpa2Psk: authValue = 3
        case .wpaWpa2Psk: authValue = 4
        case .wpa2Enterprise: authValue = 5
        case .wpa3Psk: authValue = 6
        case .wpa2Wpa3Psk: authValue = 7
        case .UNRECOGNIZED(let v): authValue = v
        }
        return [
            "ssid": network.ssid,
            "rssi": Int(network.rssi),
            "authMode": authValue,
            "channel": Int(network.channel),
            "bssid": bssidString,
        ]
    }

    private func emit(
        phase: String,
        deviceId: String? = nil,
        message: String? = nil,
        result: [String: Any?]? = nil
    ) {
        var payload: [String: Any?] = ["phase": phase]
        if let deviceId = deviceId { payload["deviceId"] = deviceId }
        if let message = message { payload["message"] = message }
        if let result = result { payload["result"] = result }
        DispatchQueue.main.async {
            self.eventEmitter?.emit(payload)
        }
    }
}

// MARK: - PoP delegate

/// Supplies ESPProvision with the caller's Proof-of-Possession + the
/// security2 username. A new instance is created per `connect()` so that
/// the delegate captures the exact credentials supplied for that session
/// (rather than relying on mutable bridge state).
private final class PopDelegate: NSObject, ESPDeviceConnectionDelegate {
    let pop: String
    let username: String

    init(pop: String, username: String) {
        self.pop = pop
        self.username = username
    }

    func getProofOfPossesion(forDevice: ESPDevice,
                             completionHandler: @escaping (String) -> Void) {
        completionHandler(pop)
    }

    func getUsername(forDevice: ESPDevice,
                     completionHandler: @escaping (String?) -> Void) {
        completionHandler(username)
    }
}
