package com.rainybit.esp_provisioning_flutter

import kotlin.test.Test
import kotlin.test.assertNotNull

/**
 * Smoke test that the plugin class still constructs cleanly after the
 * PR #4 refactor. Real method-handler tests against the
 * `esp-idf-provisioning-android` SDK land in PR #6 (XCTest equivalents
 * on the iOS side will land the same time) — they require Robolectric or
 * an instrumented runner and an EventBus harness that isn't worth
 * standing up before SoftAP support lands in PR #5.
 */
internal class EspProvisioningFlutterPluginTest {
    @Test
    fun pluginConstructs() {
        val plugin = EspProvisioningFlutterPlugin()
        assertNotNull(plugin)
    }
}
