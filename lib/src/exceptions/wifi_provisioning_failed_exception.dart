part of 'esp_provisioning_exception.dart';

/// Thrown when the Wi-Fi provisioning step itself fails in a way the plugin
/// considers fatal — i.e. the device never returned a verdict on the
/// supplied credentials because the channel collapsed during the apply
/// phase.
///
/// Note: a device that *did* respond with a structured failure (wrong
/// passphrase, SSID not visible, etc.) is **not** an exception — that comes
/// back as a `ProvisioningResult` with a non-success status. This exception
/// is reserved for transport-level breakdowns where the caller cannot tell
/// what the device did with the credentials.
final class WifiProvisioningFailedException extends EspProvisioningException {
  /// Creates the exception.
  const WifiProvisioningFailedException({
    required super.message,
    super.cause,
  }) : super(code: 'wifi_provisioning_failed');
}
