// ErrorMapping.swift
//
// Translates ESPProvision's domain error types into the typed FlutterError
// vocabulary expected by the Dart-side `mapPlatformException`.
//
// Codes correspond 1:1 to the concrete subtypes of the sealed
// `EspProvisioningException` in `lib/src/exceptions/`:
//
//   - ble_unavailable          → BleUnavailableException
//   - permission_denied        → PermissionDeniedException (details.permission)
//   - device_not_found         → DeviceNotFoundException   (details.deviceId)
//   - pop_invalid              → PopInvalidException
//   - session_failed           → SessionFailedException
//   - wifi_provisioning_failed → WifiProvisioningFailedException
//   - softap_connection_failed → SoftApConnectionException (details.ssid)
//
// Unknown native errors deliberately fall through to `session_failed` so
// callers always receive a typed Dart exception rather than a raw
// PlatformException leaking out of the public API.

import ESPProvision
import Flutter
import Foundation

enum ErrorMapping {

    /// Maps an `ESPSessionError` to the appropriate FlutterError. Behaviour
    /// of `sessionInitError` is security-level aware: under sec1/sec2 the
    /// most common cause is a wrong PoP rejected during the
    /// SRP6a / X25519 handshake, so we map to `pop_invalid` to drive the
    /// "re-prompt for PoP" UX. Under sec0 the same error means a generic
    /// handshake mismatch, so we fall through to `session_failed`.
    static func flutterError(
        forSessionError error: ESPSessionError,
        security: ESPSecurity,
        ssidOrName: String
    ) -> FlutterError {
        switch error {
        case .noPOP:
            return FlutterError(
                code: "pop_invalid",
                message: "Proof-of-Possession was not supplied to the device handshake",
                details: nil)
        case .sessionInitError:
            if security == .secure || security == .secure2 {
                return FlutterError(
                    code: "pop_invalid",
                    message: "Secure session handshake failed — typically a wrong PoP",
                    details: nil)
            }
            return FlutterError(
                code: "session_failed",
                message: error.description,
                details: nil)
        case .securityMismatch, .encryptionError:
            return FlutterError(
                code: "session_failed",
                message: error.description,
                details: nil)
        case .softAPConnectionFailure:
            return FlutterError(
                code: "softap_connection_failed",
                message: error.description,
                details: ["ssid": ssidOrName])
        case .bleFailedToConnect:
            return FlutterError(
                code: "device_not_found",
                message: error.description,
                details: ["deviceId": ssidOrName])
        case .versionInfoError, .sendDataError, .sessionNotEstablished, .noUsername:
            return FlutterError(
                code: "session_failed",
                message: error.description,
                details: nil)
        }
    }

    /// Wi-Fi scan failures are not security-sensitive; map them all to
    /// `session_failed` so the caller can retry the scan without
    /// re-prompting the user for credentials.
    static func flutterError(forWifiScanError error: ESPWiFiScanError) -> FlutterError {
        return FlutterError(
            code: "session_failed",
            message: error.description,
            details: nil)
    }

    /// Maps an `ESPProvisionError` to a `ProvisioningResult` map (delivered
    /// in-band to the Dart side as a success completion). Callers above
    /// should special-case `.wifiStatusDisconnected` themselves and raise
    /// `wifi_provisioning_failed` instead of using this map — the
    /// channel-level breakdown is an exception, not a result.
    static func provisioningResultMap(for error: ESPProvisionError) -> [String: Any?] {
        switch error {
        case .wifiStatusAuthenticationError:
            return [
                "status": "authFailed",
                "rawCode": error.code,
                "rawMessage": error.description,
            ]
        case .wifiStatusNetworkNotFound:
            return [
                "status": "networkNotFound",
                "rawCode": error.code,
                "rawMessage": error.description,
            ]
        case .configurationError(let underlying):
            return [
                "status": "deviceInternalError",
                "rawCode": error.code,
                "rawMessage": "configurationError: \(underlying.localizedDescription)",
            ]
        case .wifiStatusError(let underlying):
            return [
                "status": "unknown",
                "rawCode": error.code,
                "rawMessage": "wifiStatusError: \(underlying.localizedDescription)",
            ]
        case .wifiStatusUnknownError, .unknownError, .sessionError:
            return [
                "status": "unknown",
                "rawCode": error.code,
                "rawMessage": error.description,
            ]
        case .threadStatusError, .threadStatusDettached,
             .threadDatasetInvalid, .threadStatusNetworkNotFound,
             .threadStatusUnknownError:
            // Thread provisioning isn't part of the Dart surface yet; if a
            // Thread-only firmware response leaks through we mark it
            // unknown so callers don't misinterpret it as a Wi-Fi failure.
            return [
                "status": "unknown",
                "rawCode": error.code,
                "rawMessage": "thread error: \(error.description)",
            ]
        case .wifiStatusDisconnected:
            // Shouldn't reach here — the bridge surfaces this as an
            // exception. Map to a result anyway as a defensive fallback.
            return [
                "status": "deviceInternalError",
                "rawCode": error.code,
                "rawMessage": error.description,
            ]
        }
    }
}
