package com.rainybit.esp_provisioning_flutter

import com.espressif.provisioning.ESPConstants
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Pure-function tests for the Android error-mapping layer. Mirrors the
 * iOS `ErrorMappingTests` so that the security-aware
 * sessionInitError → pop_invalid contract is enforced on both
 * platforms simultaneously.
 *
 * These tests do not touch the ESPProvision SDK and require no
 * Android runtime context — they run on the JVM via
 * `./gradlew :esp_provisioning_flutter:testDebugUnitTest`.
 */
internal class ErrorMappingTest {

    @Test
    fun `SECURITY_2 connect failure maps to pop_invalid`() {
        val err = ErrorMapping.connectError(
            cause = RuntimeException("handshake mismatch"),
            security = ESPConstants.SecurityType.SECURITY_2,
            deviceId = "AA:BB:CC"
        )
        assertEquals("pop_invalid", err.code)
    }

    @Test
    fun `SECURITY_1 connect failure maps to pop_invalid`() {
        val err = ErrorMapping.connectError(
            cause = RuntimeException("handshake mismatch"),
            security = ESPConstants.SecurityType.SECURITY_1,
            deviceId = "AA:BB:CC"
        )
        assertEquals("pop_invalid", err.code)
    }

    @Test
    fun `SECURITY_0 connect failure falls through to session_failed`() {
        val err = ErrorMapping.connectError(
            cause = RuntimeException("oops"),
            security = ESPConstants.SecurityType.SECURITY_0,
            deviceId = "AA:BB:CC"
        )
        assertEquals("session_failed", err.code)
    }

    @Test
    fun `connect failure without cause still maps to pop_invalid under sec2`() {
        val err = ErrorMapping.connectFailedWithoutCause(
            ESPConstants.SecurityType.SECURITY_2)
        assertEquals("pop_invalid", err.code)
    }

    @Test
    fun `AUTH_FAILED provision reason yields in-band authFailed result`() {
        val map = ErrorMapping.provisioningResultMap(
            ESPConstants.ProvisionFailureReason.AUTH_FAILED)
        assertEquals("authFailed", map["status"])
    }

    @Test
    fun `NETWORK_NOT_FOUND provision reason yields in-band networkNotFound result`() {
        val map = ErrorMapping.provisioningResultMap(
            ESPConstants.ProvisionFailureReason.NETWORK_NOT_FOUND)
        assertEquals("networkNotFound", map["status"])
    }

    @Test
    fun `DEVICE_DISCONNECTED provision reason yields in-band deviceInternalError result`() {
        val map = ErrorMapping.provisioningResultMap(
            ESPConstants.ProvisionFailureReason.DEVICE_DISCONNECTED)
        assertEquals("deviceInternalError", map["status"])
    }

    @Test
    fun `wifi scan errors map to session_failed`() {
        val err = ErrorMapping.wifiScanError(RuntimeException("scan failed"))
        assertEquals("session_failed", err.code)
        assertTrue(err.message?.contains("scan failed") ?: false)
    }

    @Test
    fun `unsolicited disconnect maps to session_failed`() {
        val err = ErrorMapping.unsolicitedDisconnect("link dropped")
        assertEquals("session_failed", err.code)
        assertEquals("link dropped", err.message)
    }

    @Test
    fun `provisioning channel error maps to wifi_provisioning_failed`() {
        val err = ErrorMapping.provisioningChannelError(
            RuntimeException("channel collapsed"))
        assertEquals("wifi_provisioning_failed", err.code)
    }
}
