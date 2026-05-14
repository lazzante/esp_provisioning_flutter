part of 'esp_provisioning_exception.dart';

/// Thrown when the supplied Proof-of-Possession (PoP) string does not match
/// the value baked into the device firmware.
///
/// The native SDKs detect this during the SRP6a / X25519 handshake — a
/// wrong PoP causes the authenticated key exchange to fail before the
/// session is established. Treat it as the canonical "wrong password" signal
/// and prompt the user to re-enter the PoP from the device sticker or QR
/// code; do not retry silently.
final class PopInvalidException extends EspProvisioningException {
  /// Creates the exception.
  const PopInvalidException({
    required super.message,
    super.cause,
  }) : super(code: 'pop_invalid');
}
