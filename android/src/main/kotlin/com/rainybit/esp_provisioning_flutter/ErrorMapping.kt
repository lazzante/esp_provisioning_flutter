package com.rainybit.esp_provisioning_flutter

import com.espressif.provisioning.ESPConstants

/**
 * Tuple representing a FlutterError before it is materialised on the
 * method-channel result. Carries the same three positional fields that
 * `MethodChannel.Result.error(code, message, details)` takes, so call
 * sites can hand it straight through after marshalling to the main
 * thread.
 */
internal data class FlutterErrorTuple(
    val code: String,
    val message: String?,
    val details: Any?
)

/**
 * Translates esp-idf-provisioning-android's error surface into the typed
 * FlutterError vocabulary expected by the Dart-side `mapPlatformException`.
 *
 * Codes mirror the Swift `ErrorMapping` verbatim — the contract is the
 * sealed Dart `EspProvisioningException` hierarchy, and both native sides
 * route through the same set of strings:
 *
 *   - ble_unavailable          → BleUnavailableException
 *   - permission_denied        → PermissionDeniedException (details.permission)
 *   - device_not_found         → DeviceNotFoundException   (details.deviceId)
 *   - pop_invalid              → PopInvalidException
 *   - session_failed           → SessionFailedException
 *   - wifi_provisioning_failed → WifiProvisioningFailedException
 *   - softap_connection_failed → SoftApConnectionException (details.ssid)
 *
 * Unknown SDK exceptions fall through to `session_failed` so the Dart
 * side never receives a raw stacktrace leak.
 */
internal object ErrorMapping {

    /**
     * Maps a connect-time exception (delivered via DeviceConnectionEvent's
     * payload, or from a synchronous SDK throw) into a FlutterErrorTuple.
     *
     * Behaviour is security-aware: a generic session failure under
     * SECURITY_1 / SECURITY_2 is almost always a PoP mismatch detected
     * during the SRP6a / X25519 handshake, so we map it to `pop_invalid`
     * to drive the "re-prompt for PoP" UX. Under SECURITY_0 there is no
     * handshake so the same exception means a different kind of breakage
     * and falls through to `session_failed`.
     */
    fun connectError(
        cause: Throwable?,
        security: ESPConstants.SecurityType,
        @Suppress("UNUSED_PARAMETER") deviceId: String
    ): FlutterErrorTuple {
        val message = cause?.message
            ?: cause?.javaClass?.simpleName
            ?: "Device connection failed"
        return when (security) {
            ESPConstants.SecurityType.SECURITY_1,
            ESPConstants.SecurityType.SECURITY_2 -> FlutterErrorTuple(
                "pop_invalid",
                "Secure session handshake failed — typically a wrong PoP. ($message)",
                null
            )
            else -> FlutterErrorTuple("session_failed", message, null)
        }
    }

    /** Connect failed before the secure session was established but with
     *  no exception payload from the SDK — surfaces as session_failed
     *  irrespective of security level. */
    fun connectFailedWithoutCause(security: ESPConstants.SecurityType): FlutterErrorTuple {
        return connectError(null, security, "")
    }

    /** Unsolicited transport teardown after a session was already
     *  established. No `pop_invalid` ambiguity — the PoP was accepted
     *  earlier, so the failure is by definition a session-layer
     *  breakdown. */
    fun unsolicitedDisconnect(message: String?): FlutterErrorTuple {
        return FlutterErrorTuple(
            "session_failed",
            message ?: "Device disconnected unexpectedly",
            null
        )
    }

    /** Wi-Fi scan failures are non-security-sensitive; map all to
     *  `session_failed` so the caller can retry without re-prompting
     *  credentials. */
    fun wifiScanError(cause: Throwable?): FlutterErrorTuple {
        return FlutterErrorTuple(
            "session_failed",
            cause?.message ?: "Wi-Fi scan failed",
            null
        )
    }

    /** Maps a [ESPConstants.ProvisionFailureReason] to a `ProvisioningResult`
     *  map delivered in-band to the Dart side. AUTH_FAILED /
     *  NETWORK_NOT_FOUND are NOT exceptions — the user remedies them by
     *  re-entering input. */
    fun provisioningResultMap(reason: ESPConstants.ProvisionFailureReason): Map<String, Any?> {
        return when (reason) {
            ESPConstants.ProvisionFailureReason.AUTH_FAILED -> mapOf(
                "status" to "authFailed",
                "rawCode" to 1,
                "rawMessage" to "Device rejected the supplied passphrase"
            )
            ESPConstants.ProvisionFailureReason.NETWORK_NOT_FOUND -> mapOf(
                "status" to "networkNotFound",
                "rawCode" to 2,
                "rawMessage" to "Device could not see the supplied SSID"
            )
            ESPConstants.ProvisionFailureReason.DEVICE_DISCONNECTED -> mapOf(
                "status" to "deviceInternalError",
                "rawCode" to 3,
                "rawMessage" to "Device disconnected during credential apply"
            )
            ESPConstants.ProvisionFailureReason.UNKNOWN -> mapOf(
                "status" to "unknown",
                "rawCode" to 99,
                "rawMessage" to "Device reported an unknown provisioning failure"
            )
        }
    }

    /** Maps an arbitrary `provision()` exception (network drop, encryption
     *  failure, etc.) to a transport-level FlutterErrorTuple. Unlike
     *  [provisioningResultMap] this returns an exception envelope — the
     *  channel between phone and device collapsed before the device
     *  could report a verdict. */
    fun provisioningChannelError(cause: Throwable?): FlutterErrorTuple {
        return FlutterErrorTuple(
            "wifi_provisioning_failed",
            cause?.message ?: "Provisioning channel collapsed before device reported verdict",
            null
        )
    }

    /** Maps a sendDataToCustomEndPoint failure into a `session_failed`
     *  FlutterErrorTuple — if the custom endpoint fails the underlying
     *  secure channel has problems. */
    fun customDataError(cause: Throwable?): FlutterErrorTuple {
        return FlutterErrorTuple(
            "session_failed",
            cause?.message ?: "sendDataToCustomEndPoint failed",
            null
        )
    }
}
