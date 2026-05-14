part of 'esp_provisioning_exception.dart';

/// Thrown when an operation expected a specific device to be reachable but
/// could not find it.
///
/// Common causes: the device powered down, drifted out of BLE range, the
/// advertised name no longer matches the configured prefix, or another
/// phone claimed the connection first. Surfaced from `connect`, and from
/// post-connect operations if the link drops before a result is received.
final class DeviceNotFoundException extends EspProvisioningException {
  /// Creates the exception. [deviceId] is the identifier the caller used to
  /// reference the missing device (typically the `EspDevice.id` value).
  const DeviceNotFoundException({
    required super.message,
    required this.deviceId,
    super.cause,
  }) : super(code: 'device_not_found');

  /// The identifier of the device that could not be located.
  final String deviceId;

  @override
  String toString() =>
      'DeviceNotFoundException($code, deviceId=$deviceId): $message';
}
