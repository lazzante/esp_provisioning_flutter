import 'package:flutter/services.dart';

import 'esp_provisioning_exception.dart';

/// Translates a raw [PlatformException] into the typed
/// [EspProvisioningException] hierarchy.
///
/// The native plugins emit `PlatformException` with a stable
/// [PlatformException.code] equal to one of the codes documented on each
/// exception subclass; this helper performs the dispatch. Unknown codes fall
/// through to a [SessionFailedException] with the original code preserved in
/// the message, so callers always receive a typed error rather than a raw
/// `PlatformException` leaking out of the public API.
///
/// Internal: not re-exported from the package barrel.
EspProvisioningException mapPlatformException(PlatformException error) {
  final message = error.message ?? error.code;
  switch (error.code) {
    case 'ble_unavailable':
      return BleUnavailableException(message: message, cause: error);
    case 'permission_denied':
      final permission = (error.details is Map)
          ? (error.details as Map)['permission']?.toString() ?? 'unknown'
          : 'unknown';
      return PermissionDeniedException(
        message: message,
        permission: permission,
        cause: error,
      );
    case 'device_not_found':
      final deviceId = (error.details is Map)
          ? (error.details as Map)['deviceId']?.toString() ?? 'unknown'
          : 'unknown';
      return DeviceNotFoundException(
        message: message,
        deviceId: deviceId,
        cause: error,
      );
    case 'pop_invalid':
      return PopInvalidException(message: message, cause: error);
    case 'session_failed':
      return SessionFailedException(message: message, cause: error);
    case 'wifi_provisioning_failed':
      return WifiProvisioningFailedException(message: message, cause: error);
    case 'softap_connection_failed':
      final ssid = (error.details is Map)
          ? (error.details as Map)['ssid']?.toString() ?? ''
          : '';
      return SoftApConnectionException(
        message: message,
        ssid: ssid,
        cause: error,
      );
    default:
      return SessionFailedException(
        message: 'Unmapped native error "${error.code}": $message',
        cause: error,
      );
  }
}
