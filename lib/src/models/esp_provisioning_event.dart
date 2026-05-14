import 'package:meta/meta.dart';

import 'provisioning_result.dart';

/// The lifecycle phase emitted by [EspProvisioning.events] as a provisioning
/// flow progresses. Useful for driving progress UI without polling the
/// imperative API.
enum EspProvisioningPhase {
  /// A BLE/SoftAP scan has started.
  scanStarted,

  /// A scan finished — listeners can read results from the imperative API.
  scanFinished,

  /// The plugin began opening a transport connection to the device.
  connecting,

  /// Transport connected; the secure session is being established.
  sessionEstablishing,

  /// Secure session is fully established and the device is ready to receive
  /// commands.
  sessionEstablished,

  /// The plugin is asking the device to scan for Wi-Fi networks.
  wifiScanning,

  /// The plugin has sent credentials and is awaiting an apply result.
  applyingCredentials,

  /// A terminal provisioning result has been received from the device.
  finished,

  /// The transport has been torn down (either by [EspProvisioning.disconnect]
  /// or by an upstream failure).
  disconnected,
}

/// A lifecycle event emitted by [EspProvisioning.events].
///
/// Events are advisory — the imperative API methods still return the
/// authoritative result. They exist so that UIs can show "Connecting…" /
/// "Verifying…" without having to interleave their own state machine with
/// the plugin calls.
@immutable
class EspProvisioningEvent {
  /// Creates a lifecycle event.
  const EspProvisioningEvent({
    required this.phase,
    this.deviceId,
    this.result,
    this.message,
  });

  /// Which phase the flow has transitioned into.
  final EspProvisioningPhase phase;

  /// The device the phase refers to, if any. Always set for connection /
  /// session / provisioning phases; usually `null` for global scan events.
  final String? deviceId;

  /// The terminal result, only set when [phase] is
  /// [EspProvisioningPhase.finished].
  final ProvisioningResult? result;

  /// Optional human-readable description of the transition. Plugins should
  /// not parse this; it is intended for log lines.
  final String? message;

  /// Decodes an event from a method-channel map.
  factory EspProvisioningEvent.fromMap(Map<Object?, Object?> map) {
    final phaseRaw = map['phase'];
    if (phaseRaw is! String) {
      throw const FormatException(
        'EspProvisioningEvent.fromMap: missing/invalid "phase"',
      );
    }
    final deviceId = map['deviceId'];
    if (deviceId != null && deviceId is! String) {
      throw const FormatException(
        'EspProvisioningEvent.fromMap: "deviceId" must be String',
      );
    }
    final message = map['message'];
    if (message != null && message is! String) {
      throw const FormatException(
        'EspProvisioningEvent.fromMap: "message" must be String',
      );
    }
    final resultRaw = map['result'];
    ProvisioningResult? result;
    if (resultRaw != null) {
      if (resultRaw is! Map) {
        throw const FormatException(
          'EspProvisioningEvent.fromMap: "result" must be a map',
        );
      }
      result = ProvisioningResult.fromMap(
        Map<Object?, Object?>.from(resultRaw),
      );
    }
    return EspProvisioningEvent(
      phase: _parsePhase(phaseRaw),
      deviceId: deviceId as String?,
      message: message as String?,
      result: result,
    );
  }

  static EspProvisioningPhase _parsePhase(String raw) {
    switch (raw) {
      case 'scanStarted':
        return EspProvisioningPhase.scanStarted;
      case 'scanFinished':
        return EspProvisioningPhase.scanFinished;
      case 'connecting':
        return EspProvisioningPhase.connecting;
      case 'sessionEstablishing':
        return EspProvisioningPhase.sessionEstablishing;
      case 'sessionEstablished':
        return EspProvisioningPhase.sessionEstablished;
      case 'wifiScanning':
        return EspProvisioningPhase.wifiScanning;
      case 'applyingCredentials':
        return EspProvisioningPhase.applyingCredentials;
      case 'finished':
        return EspProvisioningPhase.finished;
      case 'disconnected':
        return EspProvisioningPhase.disconnected;
      default:
        throw FormatException('Unknown EspProvisioningPhase: $raw');
    }
  }

  @override
  bool operator ==(Object other) {
    return other is EspProvisioningEvent &&
        other.phase == phase &&
        other.deviceId == deviceId &&
        other.result == result &&
        other.message == message;
  }

  @override
  int get hashCode => Object.hash(phase, deviceId, result, message);

  @override
  String toString() =>
      'EspProvisioningEvent(phase: $phase, deviceId: $deviceId, '
      'result: $result, message: $message)';
}
