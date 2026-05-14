import Flutter
import UIKit

/// iOS host plugin for `esp_provisioning_flutter`.
///
/// PR #2 ships method/event channel scaffolding only — every imperative
/// method responds with `FlutterMethodNotImplemented` and the event channel
/// emits no events. PR #3 will wire these handlers to Espressif's
/// `ESPProvision` Pod (X25519/AES-GCM session, BLE GATT transport, custom
/// data endpoints).
///
/// Channel naming: `com.rainybit.esp_provisioning_flutter/methods` for RPC,
/// `com.rainybit.esp_provisioning_flutter/events` for the lifecycle stream.
/// The Dart-side `MethodChannelEspProvisioning` references these strings
/// verbatim — keep in sync if either side renames.
public class EspProvisioningFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private static let methodChannelName = "com.rainybit.esp_provisioning_flutter/methods"
  private static let eventChannelName = "com.rainybit.esp_provisioning_flutter/events"

  private var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = EspProvisioningFlutterPlugin()

    let methodChannel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(instance, channel: methodChannel)

    let eventChannel = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: registrar.messenger()
    )
    eventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "scanBleDevices",
         "stopBleScan",
         "connect",
         "scanWifiNetworks",
         "provisionWifi",
         "sendCustomData",
         "disconnect":
      // Wired in PR #3 once the ESPProvision Pod is integrated.
      result(FlutterMethodNotImplemented)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}
