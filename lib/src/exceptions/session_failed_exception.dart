part of 'esp_provisioning_exception.dart';

/// Thrown when the secure provisioning session could not be established or
/// has terminated unexpectedly — for example a key-exchange failure that is
/// not a wrong PoP, a transport drop mid-handshake, or a session-layer
/// protocol error reported by the native SDK.
///
/// If the failure was specifically the PoP being wrong, [PopInvalidException]
/// is thrown instead so callers can disambiguate "wrong secret" from "channel
/// broke" — the user remedies differ.
final class SessionFailedException extends EspProvisioningException {
  /// Creates the exception. The default [code] is `session_failed`; callers
  /// inside this library may override it for finer-grained dispatch when the
  /// failure is conceptually a session problem (e.g. a missing native plugin
  /// implementation).
  const SessionFailedException({
    required super.message,
    super.cause,
    super.code = 'session_failed',
  });
}
