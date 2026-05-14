import 'package:meta/meta.dart';

/// The terminal outcome of a Wi-Fi provisioning attempt as reported by the
/// ESP32 device once it has applied the supplied credentials.
enum ProvisioningStatus {
  /// The device joined the access point and reported success back over the
  /// provisioning channel.
  success,

  /// The credentials were accepted as well-formed but the device could not
  /// authenticate (e.g. wrong passphrase, EAP failure). Distinct from
  /// [networkNotFound] so UIs can prompt for a corrected passphrase.
  authFailed,

  /// The SSID was not visible to the device when it attempted to join. The
  /// network may be out of range or on a band the device cannot scan.
  networkNotFound,

  /// The device's provisioning manager reported an internal error not
  /// covered by the more specific failure modes above.
  deviceInternalError,

  /// The native side could not classify the failure. Inspect
  /// [ProvisioningResult.rawCode] / [ProvisioningResult.rawMessage] for any
  /// hints supplied by the underlying SDK.
  unknown,
}

/// The envelope returned by [EspProvisioning.provisionWifi] once the device
/// has finished attempting to apply the supplied credentials.
///
/// Even when [status] is not [ProvisioningStatus.success], the call resolves
/// normally — failures during the credential-apply phase are reported in-band
/// here rather than as exceptions, because they typically require the
/// end-user to correct an input (e.g. retype the passphrase) rather than
/// indicating a programmer error. Exceptions are reserved for unrecoverable
/// problems such as a lost BLE link or a session cipher failure.
@immutable
class ProvisioningResult {
  /// Creates a result envelope. Prefer the named constructors
  /// [ProvisioningResult.success] and [ProvisioningResult.failure].
  const ProvisioningResult({
    required this.status,
    this.rawCode,
    this.rawMessage,
  });

  /// Convenience constructor for the success path.
  const ProvisioningResult.success()
    : this(status: ProvisioningStatus.success);

  /// Convenience constructor for a known failure category.
  const ProvisioningResult.failure({
    required ProvisioningStatus status,
    int? rawCode,
    String? rawMessage,
  }) : this(status: status, rawCode: rawCode, rawMessage: rawMessage);

  /// The terminal classification of the attempt.
  final ProvisioningStatus status;

  /// The integer reason code the native SDK reported, if any. Useful for
  /// telemetry but should not be used to branch UI behaviour — prefer
  /// matching on [status].
  final int? rawCode;

  /// The free-form message the native SDK reported, if any.
  final String? rawMessage;

  /// Whether the device joined the access point.
  bool get isSuccess => status == ProvisioningStatus.success;

  /// Decodes a result from the method-channel map representation.
  factory ProvisioningResult.fromMap(Map<Object?, Object?> map) {
    final statusRaw = map['status'];
    if (statusRaw is! String) {
      throw const FormatException(
        'ProvisioningResult.fromMap: missing/invalid "status"',
      );
    }
    final rawCode = map['rawCode'];
    if (rawCode != null && rawCode is! int) {
      throw const FormatException(
        'ProvisioningResult.fromMap: "rawCode" must be int',
      );
    }
    final rawMessage = map['rawMessage'];
    if (rawMessage != null && rawMessage is! String) {
      throw const FormatException(
        'ProvisioningResult.fromMap: "rawMessage" must be String',
      );
    }
    return ProvisioningResult(
      status: _parseStatus(statusRaw),
      rawCode: rawCode as int?,
      rawMessage: rawMessage as String?,
    );
  }

  /// Encodes this result as a method-channel-safe map.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'status': _encodeStatus(status),
      'rawCode': rawCode,
      'rawMessage': rawMessage,
    };
  }

  static ProvisioningStatus _parseStatus(String raw) {
    switch (raw) {
      case 'success':
        return ProvisioningStatus.success;
      case 'authFailed':
        return ProvisioningStatus.authFailed;
      case 'networkNotFound':
        return ProvisioningStatus.networkNotFound;
      case 'deviceInternalError':
        return ProvisioningStatus.deviceInternalError;
      case 'unknown':
        return ProvisioningStatus.unknown;
      default:
        return ProvisioningStatus.unknown;
    }
  }

  static String _encodeStatus(ProvisioningStatus status) {
    switch (status) {
      case ProvisioningStatus.success:
        return 'success';
      case ProvisioningStatus.authFailed:
        return 'authFailed';
      case ProvisioningStatus.networkNotFound:
        return 'networkNotFound';
      case ProvisioningStatus.deviceInternalError:
        return 'deviceInternalError';
      case ProvisioningStatus.unknown:
        return 'unknown';
    }
  }

  @override
  bool operator ==(Object other) {
    return other is ProvisioningResult &&
        other.status == status &&
        other.rawCode == rawCode &&
        other.rawMessage == rawMessage;
  }

  @override
  int get hashCode => Object.hash(status, rawCode, rawMessage);

  @override
  String toString() =>
      'ProvisioningResult(status: $status, rawCode: $rawCode, '
      'rawMessage: $rawMessage)';
}
