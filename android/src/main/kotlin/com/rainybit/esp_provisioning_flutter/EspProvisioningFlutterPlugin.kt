package com.rainybit.esp_provisioning_flutter

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Android host plugin for `esp_provisioning_flutter`.
 *
 * Owns the method channel, the event channel, and the [ProvisioningBridge]
 * instance that talks to Espressif's `esp-idf-provisioning-android` SDK.
 * The plugin class itself is deliberately thin — every non-trivial
 * decision lives in the bridge, mirroring the iOS-side split between
 * `EspProvisioningFlutterPlugin.swift` and `ProvisioningBridge.swift`.
 */
class EspProvisioningFlutterPlugin :
    FlutterPlugin,
    MethodCallHandler,
    EventChannel.StreamHandler,
    EspEventEmitter {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var bridge: ProvisioningBridge? = null
    private var applicationContext: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        bridge = ProvisioningBridge(binding.applicationContext, this)

        methodChannel = MethodChannel(
            binding.binaryMessenger,
            "com.rainybit.esp_provisioning_flutter/methods"
        )
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(
            binding.binaryMessenger,
            "com.rainybit.esp_provisioning_flutter/events"
        )
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val bridge = this.bridge ?: run {
            result.error(
                "session_failed",
                "Plugin not attached to a Flutter engine yet",
                null
            )
            return
        }
        when (call.method) {
            "scanBleDevices" -> {
                val prefix = call.argument<String>("devicePrefix")
                val timeoutMs = call.argument<Int>("timeoutMs")
                if (prefix == null || timeoutMs == null) {
                    result.error(
                        "session_failed",
                        "Invalid arguments for 'scanBleDevices'",
                        null
                    )
                    return
                }
                bridge.scanBleDevices(prefix, timeoutMs, result)
            }
            "stopBleScan" -> bridge.stopBleScan(result)
            "scanSoftApDevices" -> {
                val prefix = call.argument<String>("devicePrefix")
                val timeoutMs = call.argument<Int>("timeoutMs")
                if (prefix == null || timeoutMs == null) {
                    result.error(
                        "session_failed",
                        "Invalid arguments for 'scanSoftApDevices'",
                        null
                    )
                    return
                }
                bridge.scanSoftApDevices(prefix, timeoutMs, result)
            }
            "connect" -> {
                @Suppress("UNCHECKED_CAST")
                val deviceMap = call.argument<Map<String, Any?>>("device")
                val pop = call.argument<String>("proofOfPossession")
                val security = call.argument<Int>("security")
                val softApPassphrase = call.argument<String>("softApPassphrase")
                if (deviceMap == null || pop == null || security == null) {
                    result.error(
                        "session_failed",
                        "Invalid arguments for 'connect'",
                        null
                    )
                    return
                }
                bridge.connect(deviceMap, pop, security, softApPassphrase, result)
            }
            "scanWifiNetworks" -> bridge.scanWifiNetworks(result)
            "provisionWifi" -> {
                val ssid = call.argument<String>("ssid")
                val passphrase = call.argument<String>("passphrase")
                if (ssid == null || passphrase == null) {
                    result.error(
                        "session_failed",
                        "Invalid arguments for 'provisionWifi'",
                        null
                    )
                    return
                }
                bridge.provisionWifi(ssid, passphrase, result)
            }
            "sendCustomData" -> {
                val endpoint = call.argument<String>("endpoint")
                val data = call.argument<ByteArray>("data")
                if (endpoint == null || data == null) {
                    result.error(
                        "session_failed",
                        "Invalid arguments for 'sendCustomData'",
                        null
                    )
                    return
                }
                bridge.sendCustomData(endpoint, data, result)
            }
            "disconnect" -> bridge.disconnect(result)
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        bridge?.dispose()
        bridge = null
        applicationContext = null
    }

    // MARK: - EspEventEmitter

    override fun emit(event: Map<String, Any?>) {
        // EventSink may be nil if no Dart-side listener is attached;
        // events are advisory and the imperative API still returns the
        // authoritative result, so we drop silently rather than buffer.
        eventSink?.success(event)
    }
}
