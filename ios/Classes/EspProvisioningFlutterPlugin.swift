import Flutter
import UIKit

/// iOS host plugin for `esp_provisioning_flutter`.
///
/// Owns the method channel, the event channel, and the `ProvisioningBridge`
/// instance that talks to Espressif's `ESPProvision` SDK. The plugin class
/// itself is deliberately thin — every non-trivial decision lives in the
/// bridge, so the bridge can be unit-tested in isolation later (PR #6) and
/// so this class remains a near-pure wire format adapter.
public class EspProvisioningFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, EspEventEmitter {

    private static let methodChannelName = "com.rainybit.esp_provisioning_flutter/methods"
    private static let eventChannelName = "com.rainybit.esp_provisioning_flutter/events"

    private var eventSink: FlutterEventSink?
    private var bridge: ProvisioningBridge!

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = EspProvisioningFlutterPlugin()
        instance.bridge = ProvisioningBridge(eventEmitter: instance)

        let methodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "scanBleDevices":
            guard let args = call.arguments as? [String: Any],
                  let prefix = args["devicePrefix"] as? String,
                  let timeoutMs = args["timeoutMs"] as? Int else {
                result(invalidArgumentsError(for: call.method))
                return
            }
            bridge.scanBleDevices(devicePrefix: prefix,
                                  timeoutMs: timeoutMs,
                                  result: result)

        case "stopBleScan":
            bridge.stopBleScan(result: result)

        case "connect":
            guard let args = call.arguments as? [String: Any],
                  let deviceMap = args["device"] as? [String: Any?],
                  let pop = args["proofOfPossession"] as? String,
                  let security = args["security"] as? Int else {
                result(invalidArgumentsError(for: call.method))
                return
            }
            bridge.connect(deviceMap: deviceMap,
                           proofOfPossession: pop,
                           security: security,
                           result: result)

        case "scanWifiNetworks":
            bridge.scanWifiNetworks(result: result)

        case "provisionWifi":
            guard let args = call.arguments as? [String: Any],
                  let ssid = args["ssid"] as? String,
                  let passphrase = args["passphrase"] as? String else {
                result(invalidArgumentsError(for: call.method))
                return
            }
            bridge.provisionWifi(ssid: ssid, passphrase: passphrase, result: result)

        case "sendCustomData":
            guard let args = call.arguments as? [String: Any],
                  let endpoint = args["endpoint"] as? String,
                  let data = args["data"] as? FlutterStandardTypedData else {
                result(invalidArgumentsError(for: call.method))
                return
            }
            bridge.sendCustomData(endpoint: endpoint, data: data, result: result)

        case "disconnect":
            bridge.disconnect(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func invalidArgumentsError(for method: String) -> FlutterError {
        return FlutterError(
            code: "session_failed",
            message: "Invalid arguments for method '\(method)'",
            details: nil)
    }

    // MARK: - FlutterStreamHandler

    public func onListen(withArguments arguments: Any?,
                         eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    // MARK: - EspEventEmitter

    func emit(_ event: [String: Any?]) {
        // EventSink may be nil if no Dart-side listener is attached; that
        // is a normal state — events are advisory and the imperative API
        // still returns the authoritative result. We drop events silently
        // rather than buffering.
        let sink = self.eventSink
        if Thread.isMainThread {
            sink?(event)
        } else {
            DispatchQueue.main.async {
                sink?(event)
            }
        }
    }
}
