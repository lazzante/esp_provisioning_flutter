/// Exception hierarchy thrown by `esp_provisioning_flutter`.
///
/// All concrete exception types are declared in this library (via `part`
/// directives) so that the [EspProvisioningException] sealed base can
/// enforce exhaustive `switch` matching at the call site.
library;

part 'ble_unavailable_exception.dart';
part 'permission_denied_exception.dart';
part 'device_not_found_exception.dart';
part 'pop_invalid_exception.dart';
part 'session_failed_exception.dart';
part 'wifi_provisioning_failed_exception.dart';
part 'softap_connection_exception.dart';

/// Sealed base class for every exception thrown by `esp_provisioning_flutter`.
///
/// Sealed so that callers can write exhaustive `switch` expressions over the
/// concrete subtypes and the analyser will complain if a future plugin
/// version adds a new failure mode the caller has not handled.
///
/// Every exception carries:
///   * [message] — a human-readable description, safe to surface in dev/QA
///     logs but generally not localised, so do not display directly to end
///     users.
///   * [code] — an opaque stable string identifying the failure category.
///     This is what the native side hands to us via `PlatformException.code`,
///     and is the most reliable thing to log to telemetry.
///   * [cause] — the underlying error object, if any, that triggered the
///     failure. Often a `PlatformException` from the method channel.
sealed class EspProvisioningException implements Exception {
  /// Initialises the base fields. Concrete subclasses pass their stable
  /// [code] verbatim.
  const EspProvisioningException({
    required this.code,
    required this.message,
    this.cause,
  });

  /// Stable, machine-readable failure identifier, e.g. `ble_unavailable`.
  final String code;

  /// Human-readable description. Not localised.
  final String message;

  /// The underlying error object, if known.
  final Object? cause;

  @override
  String toString() =>
      '$runtimeType($code): $message${cause == null ? '' : ' (cause: $cause)'}';
}
