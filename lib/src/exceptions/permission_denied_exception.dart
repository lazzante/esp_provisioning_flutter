part of 'esp_provisioning_exception.dart';

/// Thrown when the host operating system has refused the app a permission
/// required to scan or connect — typically `BLUETOOTH_SCAN` /
/// `BLUETOOTH_CONNECT` (Android 12+), `ACCESS_FINE_LOCATION` (Android 11 and
/// earlier), or `NSBluetoothAlwaysUsageDescription` (iOS).
///
/// The caller is expected to surface a UI prompt explaining the permission
/// to the user and route them to system settings if necessary; the plugin
/// does not attempt to request permissions on the user's behalf because the
/// timing of permission prompts is application-specific.
final class PermissionDeniedException extends EspProvisioningException {
  /// Creates the exception. [permission] is a free-form label identifying
  /// which permission was denied — e.g. `bluetooth_scan` or `location`.
  const PermissionDeniedException({
    required super.message,
    required this.permission,
    super.cause,
  }) : super(code: 'permission_denied');

  /// The permission identifier that was refused. Format is
  /// platform-specific; intended for logs and telemetry rather than UI.
  final String permission;

  @override
  String toString() =>
      'PermissionDeniedException($code, permission=$permission): $message';
}
