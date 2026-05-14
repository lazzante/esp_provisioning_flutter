package com.rainybit.esp_provisioning_flutter

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Android host plugin for `esp_provisioning_flutter`.
 *
 * PR #2 ships method/event channel scaffolding only — every imperative
 * method responds with `notImplemented()` and the event channel emits no
 * events. PR #4 wires these handlers to Espressif's
 * `esp-idf-provisioning-android` library (X25519/AES-GCM session, BLE GATT
 * transport, custom data endpoints) pulled in via JitPack.
 *
 * Channel naming: `com.rainybit.esp_provisioning_flutter/methods` for RPC,
 * `com.rainybit.esp_provisioning_flutter/events` for the lifecycle stream.
 * The Dart-side `MethodChannelEspProvisioning` references these strings
 * verbatim — keep in sync if either side renames.
 */
class EspProvisioningFlutterPlugin :
    FlutterPlugin,
    MethodCallHandler,
    EventChannel.StreamHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel

    @Suppress("unused")
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
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
        when (call.method) {
            "scanBleDevices",
            "stopBleScan",
            "connect",
            "scanWifiNetworks",
            "provisionWifi",
            "sendCustomData",
            "disconnect" -> {
                // Wired in PR #4 once the esp-idf-provisioning-android
                // library is integrated.
                result.notImplemented()
            }
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
    }
}
