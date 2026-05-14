part of 'esp_provisioning_exception.dart';

/// Thrown when the SoftAP transport cannot establish a Wi-Fi connection to
/// the device's provisioning access point.
///
/// On Android this typically wraps a `WifiNetworkSpecifier` rejection or a
/// `NetworkRequest` timeout from `ConnectivityManager`; on iOS it wraps a
/// `NEHotspotConfiguration` error or a `NEHotspotHelper` denial. The
/// underlying cause is preserved in [EspProvisioningException.cause] for
/// telemetry.
final class SoftApConnectionException extends EspProvisioningException {
  /// Creates the exception.
  const SoftApConnectionException({
    required super.message,
    required this.ssid,
    super.cause,
  }) : super(code: 'softap_connection_failed');

  /// The SSID the plugin attempted to associate with.
  final String ssid;

  @override
  String toString() =>
      'SoftApConnectionException($code, ssid=$ssid): $message';
}
