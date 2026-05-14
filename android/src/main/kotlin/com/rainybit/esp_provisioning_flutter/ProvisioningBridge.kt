package com.rainybit.esp_provisioning_flutter

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.le.ScanResult
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.espressif.provisioning.DeviceConnectionEvent
import com.espressif.provisioning.ESPConstants
import com.espressif.provisioning.ESPDevice
import com.espressif.provisioning.ESPProvisionManager
import com.espressif.provisioning.WiFiAccessPoint
import com.espressif.provisioning.listeners.BleScanListener
import com.espressif.provisioning.listeners.ProvisionListener
import com.espressif.provisioning.listeners.ResponseListener
import com.espressif.provisioning.listeners.WiFiScanListener
import io.flutter.plugin.common.MethodChannel
import org.greenrobot.eventbus.EventBus
import org.greenrobot.eventbus.Subscribe
import org.greenrobot.eventbus.ThreadMode

/**
 * Receives lifecycle events from the bridge. Implemented by the plugin
 * class so the bridge stays decoupled from FlutterEventChannel itself
 * (and so a fake can be substituted in unit tests).
 */
internal interface EspEventEmitter {
    fun emit(event: Map<String, Any?>)
}

/**
 * Default username for ESP-IDF security2 firmware. Production fleets may
 * override this in firmware; if that happens we'd plumb a `username`
 * parameter through `connect()` on the Dart side. Today every device we
 * ship uses the stock value.
 */
private const val DEFAULT_SECURITY2_USERNAME = "wifiprov"

/**
 * Wraps Espressif's `ESPProvisionManager` / `ESPDevice` callback API
 * behind a single per-plugin state machine: discovered-device cache,
 * in-flight scan + connect guards, EventBus subscription for connection
 * lifecycle, and main-thread marshalling of every callback.
 *
 * Mirrors the iOS-side `ProvisioningBridge.swift` 1:1 in semantics. Not
 * thread-safe on its own — every public method must be invoked from the
 * Flutter UI thread (which the method channel guarantees).
 */
internal class ProvisioningBridge(
    private val applicationContext: Context,
    private val eventEmitter: EspEventEmitter
) {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val provisionManager: ESPProvisionManager =
        ESPProvisionManager.getInstance(applicationContext)

    /** Discovered devices from the last scan, keyed by MAC address. The
     *  BluetoothDevice plus the primary service UUID together let us
     *  reconstruct an ESPDevice for connect() without redoing the scan. */
    private val discoveredDevices = mutableMapOf<String, DiscoveredEntry>()

    /** Holds the active ESPDevice between connect → disconnect. Released
     *  on disconnect so EventBus references and the SDK's internal
     *  retained singleton don't keep us alive. */
    private var connectedDevice: ESPDevice? = null

    /** Security used for the current/last connection, needed to make
     *  security-aware decisions in [ErrorMapping] (sec1/sec2 connect
     *  failure → pop_invalid; sec0 → session_failed). */
    private var activeSecurity: ESPConstants.SecurityType = ESPConstants.SecurityType.SECURITY_2

    // Concurrency guards.
    private var scanInFlight = false
    private var connectInFlight = false
    private var scanResult: MethodChannel.Result? = null
    private var connectResult: MethodChannel.Result? = null
    private var pendingConnectDeviceId: String = ""
    private var scanTimeoutRunnable: Runnable? = null
    private var eventBusRegistered = false

    init {
        ensureEventBusRegistered()
    }

    // MARK: - Lifecycle

    /** Tear-down hook invoked by the plugin's onDetachedFromEngine. Drops
     *  EventBus subscription, cancels any in-flight scan, and releases
     *  the connected device. */
    fun dispose() {
        cancelScanTimer()
        if (scanInFlight) {
            try {
                provisionManager.stopBleScan()
            } catch (_: Throwable) { /* best effort */ }
            scanInFlight = false
            scanResult = null
        }
        if (eventBusRegistered) {
            try {
                EventBus.getDefault().unregister(this)
            } catch (_: Throwable) { /* best effort */ }
            eventBusRegistered = false
        }
        connectedDevice = null
        discoveredDevices.clear()
    }

    private fun ensureEventBusRegistered() {
        if (!eventBusRegistered) {
            EventBus.getDefault().register(this)
            eventBusRegistered = true
        }
    }

    // MARK: - Method channel entry points

    @SuppressLint("MissingPermission") // Probe runs first; SDK enforces.
    fun scanBleDevices(devicePrefix: String, timeoutMs: Int, result: MethodChannel.Result) {
        // Cancel any previous in-flight scan first — supersede pattern.
        if (scanInFlight) {
            try {
                provisionManager.stopBleScan()
            } catch (_: Throwable) { /* best effort */ }
            cancelScanTimer()
            // Previous caller gets an empty list rather than an exception;
            // superseding scans is a normal UI pattern.
            scanResult?.success(emptyList<Map<String, Any?>>())
            scanResult = null
            scanInFlight = false
            emit(phase = "scanFinished", message = "superseded by new scan")
        }

        when (val avail = BluetoothStateProbe.check(applicationContext)) {
            BluetoothAvailability.PoweredOff -> {
                result.error(
                    "ble_unavailable",
                    "Bluetooth is off or unsupported on this device",
                    null
                )
                return
            }
            is BluetoothAvailability.PermissionDenied -> {
                result.error(
                    "permission_denied",
                    "Runtime BLE permission '${avail.permission}' is not granted",
                    mapOf("permission" to avail.permission)
                )
                return
            }
            BluetoothAvailability.Available -> Unit
        }

        scanInFlight = true
        scanResult = result
        discoveredDevices.clear()
        emit(phase = "scanStarted")

        provisionManager.searchBleEspDevices(devicePrefix, object : BleScanListener {
            override fun scanStartFailed() {
                mainHandler.post {
                    if (!scanInFlight) return@post
                    cancelScanTimer()
                    scanInFlight = false
                    emit(phase = "scanFinished", message = "scanStartFailed")
                    scanResult?.error(
                        "session_failed",
                        "Failed to start BLE scan (adapter rejected the request)",
                        null
                    )
                    scanResult = null
                }
            }

            override fun onPeripheralFound(device: BluetoothDevice, scanResult: ScanResult) {
                mainHandler.post {
                    val address = try {
                        device.address
                    } catch (_: SecurityException) {
                        return@post // missing BLUETOOTH_CONNECT — should have been caught earlier
                    }
                    val advName: String? = scanResult.scanRecord?.deviceName
                        ?: try { device.name } catch (_: SecurityException) { null }
                    val primaryUuid = scanResult.scanRecord?.serviceUuids?.firstOrNull()?.uuid?.toString()
                    val rssi = scanResult.rssi
                    discoveredDevices[address] = DiscoveredEntry(
                        bluetoothDevice = device,
                        primaryServiceUuid = primaryUuid,
                        advertisedName = advName ?: address,
                        rssi = rssi
                    )
                }
            }

            override fun scanCompleted() {
                mainHandler.post {
                    if (!scanInFlight) return@post
                    cancelScanTimer()
                    scanInFlight = false
                    emit(phase = "scanFinished")
                    scanResult?.success(discoveredDevices.values.map { it.toFlutterMap() })
                    scanResult = null
                }
            }

            override fun onFailure(e: Exception) {
                mainHandler.post {
                    if (!scanInFlight) return@post
                    cancelScanTimer()
                    scanInFlight = false
                    emit(phase = "scanFinished", message = e.message)
                    scanResult?.error(
                        "session_failed",
                        e.message ?: "BLE scan failed",
                        null
                    )
                    scanResult = null
                }
            }
        })

        // SDK's internal scan timer is hardcoded; our additional timer is a
        // defense-in-depth fallback for environments where the listener's
        // scanCompleted callback never fires (observed on certain OEM
        // Android skins).
        installScanTimer(timeoutMs)
    }

    fun stopBleScan(result: MethodChannel.Result) {
        if (scanInFlight) {
            try {
                provisionManager.stopBleScan()
            } catch (_: Throwable) { /* best effort */ }
            cancelScanTimer()
            scanInFlight = false
            emit(phase = "scanFinished", message = "stopped by caller")
            scanResult?.success(discoveredDevices.values.map { it.toFlutterMap() })
            scanResult = null
        }
        result.success(null)
    }

    @SuppressLint("MissingPermission")
    fun connect(
        deviceMap: Map<String, Any?>,
        proofOfPossession: String,
        security: Int,
        result: MethodChannel.Result
    ) {
        if (connectInFlight || connectedDevice != null) {
            result.error(
                "session_failed",
                "A connection is already in flight or established; call disconnect() first",
                null
            )
            return
        }

        val deviceId = deviceMap["id"] as? String
        if (deviceId.isNullOrEmpty()) {
            result.error(
                "session_failed",
                "connect: device map missing valid 'id'",
                null
            )
            return
        }

        val entry = discoveredDevices[deviceId]
        if (entry == null) {
            result.error(
                "device_not_found",
                "Device '$deviceId' is no longer in the scan cache. Re-scan and try again.",
                mapOf("deviceId" to deviceId)
            )
            return
        }

        val espSecurity = securityFromInt(security)
        activeSecurity = espSecurity
        connectInFlight = true
        connectResult = result
        pendingConnectDeviceId = deviceId
        ensureEventBusRegistered()

        val device = provisionManager.createESPDevice(
            ESPConstants.TransportType.TRANSPORT_BLE,
            espSecurity
        )
        device.bluetoothDevice = entry.bluetoothDevice
        device.deviceName = entry.advertisedName
        device.primaryServiceUuid = entry.primaryServiceUuid
        device.proofOfPossession = proofOfPossession
        if (espSecurity == ESPConstants.SecurityType.SECURITY_2) {
            device.userName = DEFAULT_SECURITY2_USERNAME
        }

        emit(phase = "connecting", deviceId = deviceId)
        emit(phase = "sessionEstablishing", deviceId = deviceId)

        device.connectToDevice()
        // Resolution arrives asynchronously via onDeviceConnectionEvent.
    }

    fun scanWifiNetworks(result: MethodChannel.Result) {
        val device = connectedDevice
        if (device == null) {
            result.error(
                "session_failed",
                "No active session. Call connect() first.",
                null
            )
            return
        }
        emit(phase = "wifiScanning", deviceId = device.deviceName)
        device.scanNetworks(object : WiFiScanListener {
            override fun onWifiListReceived(wifiList: ArrayList<WiFiAccessPoint>) {
                mainHandler.post {
                    result.success(wifiList.map { encodeNetwork(it) })
                }
            }

            override fun onWiFiScanFailed(e: Exception) {
                mainHandler.post {
                    val err = ErrorMapping.wifiScanError(e)
                    result.error(err.code, err.message, err.details)
                }
            }
        })
    }

    fun provisionWifi(ssid: String, passphrase: String, result: MethodChannel.Result) {
        val device = connectedDevice
        if (device == null) {
            result.error(
                "session_failed",
                "No active session. Call connect() first.",
                null
            )
            return
        }
        emit(phase = "applyingCredentials", deviceId = device.deviceName)
        device.provision(ssid, passphrase, object : ProvisionListener {
            override fun createSessionFailed(e: Exception) {
                mainHandler.post {
                    val err = ErrorMapping.connectError(e, activeSecurity, device.deviceName ?: "")
                    result.error(err.code, err.message, err.details)
                }
            }

            override fun wifiConfigSent() {
                emit(phase = "applyingCredentials",
                    deviceId = device.deviceName,
                    message = "wifiConfigSent")
            }

            override fun wifiConfigFailed(e: Exception) {
                mainHandler.post {
                    val err = ErrorMapping.provisioningChannelError(e)
                    result.error(err.code, err.message, err.details)
                }
            }

            override fun wifiConfigApplied() {
                emit(phase = "applyingCredentials",
                    deviceId = device.deviceName,
                    message = "wifiConfigApplied")
            }

            override fun wifiConfigApplyFailed(e: Exception) {
                mainHandler.post {
                    val err = ErrorMapping.provisioningChannelError(e)
                    result.error(err.code, err.message, err.details)
                }
            }

            override fun provisioningFailedFromDevice(
                failureReason: ESPConstants.ProvisionFailureReason
            ) {
                mainHandler.post {
                    val resultMap = ErrorMapping.provisioningResultMap(failureReason)
                    emit(phase = "finished",
                        deviceId = device.deviceName,
                        resultPayload = resultMap)
                    result.success(resultMap)
                }
            }

            override fun deviceProvisioningSuccess() {
                mainHandler.post {
                    val resultMap: Map<String, Any?> = mapOf("status" to "success")
                    emit(phase = "finished",
                        deviceId = device.deviceName,
                        resultPayload = resultMap)
                    result.success(resultMap)
                }
            }

            override fun onProvisioningFailed(e: Exception) {
                mainHandler.post {
                    val err = ErrorMapping.provisioningChannelError(e)
                    result.error(err.code, err.message, err.details)
                }
            }
        })
    }

    fun sendCustomData(endpoint: String, data: ByteArray, result: MethodChannel.Result) {
        val device = connectedDevice
        if (device == null) {
            result.error(
                "session_failed",
                "No active session. Call connect() first.",
                null
            )
            return
        }
        device.sendDataToCustomEndPoint(endpoint, data, object : ResponseListener {
            override fun onSuccess(returnData: ByteArray) {
                mainHandler.post { result.success(returnData) }
            }

            override fun onFailure(e: Exception) {
                mainHandler.post {
                    val err = ErrorMapping.customDataError(e)
                    result.error(err.code, err.message, err.details)
                }
            }
        })
    }

    fun disconnect(result: MethodChannel.Result) {
        val device = connectedDevice
        if (device != null) {
            try {
                device.disconnectDevice()
            } catch (_: Throwable) { /* best effort */ }
            emit(phase = "disconnected", deviceId = device.deviceName)
        }
        connectedDevice = null
        result.success(null)
    }

    // MARK: - EventBus subscriber

    /** Receives connect / disconnect lifecycle events posted by the SDK
     *  for the active ESPDevice. ThreadMode.MAIN ensures we are already
     *  on the Flutter UI thread when this fires. */
    @Subscribe(threadMode = ThreadMode.MAIN)
    fun onDeviceConnectionEvent(event: DeviceConnectionEvent) {
        when (event.eventType) {
            ESPConstants.EVENT_DEVICE_CONNECTED -> {
                if (connectInFlight) {
                    val device = provisionManager.espDevice
                    connectedDevice = device
                    val deviceId = pendingConnectDeviceId
                    emit(phase = "sessionEstablished", deviceId = deviceId)
                    connectInFlight = false
                    connectResult?.success(null)
                    connectResult = null
                    pendingConnectDeviceId = ""
                }
            }
            ESPConstants.EVENT_DEVICE_CONNECTION_FAILED -> {
                if (connectInFlight) {
                    val deviceId = pendingConnectDeviceId
                    emit(phase = "disconnected", deviceId = deviceId)
                    val err = ErrorMapping.connectFailedWithoutCause(activeSecurity)
                    connectInFlight = false
                    connectResult?.error(err.code, err.message, err.details)
                    connectResult = null
                    pendingConnectDeviceId = ""
                    connectedDevice = null
                }
            }
            ESPConstants.EVENT_DEVICE_DISCONNECTED -> {
                if (connectInFlight) {
                    // Disconnect arrived mid-handshake → reject connect.
                    val deviceId = pendingConnectDeviceId
                    emit(phase = "disconnected", deviceId = deviceId)
                    val err = ErrorMapping.unsolicitedDisconnect(
                        "Device disconnected before session established")
                    connectInFlight = false
                    connectResult?.error(err.code, err.message, err.details)
                    connectResult = null
                    pendingConnectDeviceId = ""
                    connectedDevice = null
                } else if (connectedDevice != null) {
                    // Unsolicited disconnect after we were already connected.
                    emit(phase = "disconnected", deviceId = connectedDevice?.deviceName)
                    connectedDevice = null
                }
            }
        }
    }

    // MARK: - Helpers

    private fun installScanTimer(timeoutMs: Int) {
        cancelScanTimer()
        val runnable = Runnable {
            if (!scanInFlight) return@Runnable
            try {
                provisionManager.stopBleScan()
            } catch (_: Throwable) { /* best effort */ }
            scanInFlight = false
            emit(phase = "scanFinished", message = "timeout")
            scanResult?.success(discoveredDevices.values.map { it.toFlutterMap() })
            scanResult = null
        }
        scanTimeoutRunnable = runnable
        mainHandler.postDelayed(runnable, timeoutMs.toLong().coerceAtLeast(500))
    }

    private fun cancelScanTimer() {
        scanTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        scanTimeoutRunnable = null
    }

    private fun encodeNetwork(ap: WiFiAccessPoint): Map<String, Any?> {
        return mapOf(
            "ssid" to ap.wifiName,
            "rssi" to ap.rssi,
            "authMode" to ap.security,
            "channel" to null,
            "bssid" to null,
        )
    }

    private fun securityFromInt(v: Int): ESPConstants.SecurityType {
        return when (v) {
            0 -> ESPConstants.SecurityType.SECURITY_0
            1 -> ESPConstants.SecurityType.SECURITY_1
            else -> ESPConstants.SecurityType.SECURITY_2
        }
    }

    private fun emit(
        phase: String,
        deviceId: String? = null,
        message: String? = null,
        resultPayload: Map<String, Any?>? = null
    ) {
        val payload = mutableMapOf<String, Any?>("phase" to phase)
        if (deviceId != null) payload["deviceId"] = deviceId
        if (message != null) payload["message"] = message
        if (resultPayload != null) payload["result"] = resultPayload
        if (Looper.myLooper() == Looper.getMainLooper()) {
            eventEmitter.emit(payload)
        } else {
            mainHandler.post { eventEmitter.emit(payload) }
        }
    }
}

/** Snapshot of the data we capture when a device is found in a BLE scan,
 *  retained until either the next scan or `dispose()`. */
private data class DiscoveredEntry(
    val bluetoothDevice: BluetoothDevice,
    val primaryServiceUuid: String?,
    val advertisedName: String,
    val rssi: Int,
) {
    @SuppressLint("MissingPermission")
    fun toFlutterMap(): Map<String, Any?> {
        return mapOf(
            "id" to bluetoothDevice.address,
            "name" to advertisedName,
            "transport" to "ble",
            "rssi" to rssi,
            "serviceUuid" to primaryServiceUuid,
            "bssid" to null,
        )
    }
}
