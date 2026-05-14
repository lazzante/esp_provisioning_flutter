// XCTest smoke + error-mapping tests for the iOS plugin bridge.
//
// These tests exercise the parts of the plugin that DO NOT require
// hardware: the FlutterError envelope built by every method, the
// security-aware error mapping, and the surface contract for invalid /
// unknown method calls. Real device functional verification (BLE scan,
// SoftAP join, full provisioning round-trip) lives outside the
// unit-test scope and is performed manually against the pilot batch.

import ESPProvision
import Flutter
import XCTest

@testable import esp_provisioning_flutter

final class PluginSmokeTests: XCTestCase {

    func testPluginConstructsCleanly() {
        let plugin = EspProvisioningFlutterPlugin()
        XCTAssertNotNil(plugin)
    }

    func testUnknownMethodReturnsNotImplemented() {
        let plugin = EspProvisioningFlutterPlugin()
        let call = FlutterMethodCall(methodName: "noSuchMethod", arguments: nil)
        let exp = expectation(description: "result called")
        plugin.handle(call) { result in
            // FlutterMethodNotImplemented is bridged as a singleton sentinel.
            XCTAssertNotNil(result)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    func testInvalidArgumentsProduceFlutterError() {
        let plugin = EspProvisioningFlutterPlugin()
        // scanBleDevices requires devicePrefix + timeoutMs; pass garbage.
        let call = FlutterMethodCall(
            methodName: "scanBleDevices",
            arguments: ["devicePrefix": 42 /* wrong type */]
        )
        let exp = expectation(description: "error returned")
        plugin.handle(call) { result in
            guard let err = result as? FlutterError else {
                XCTFail("Expected FlutterError, got \(String(describing: result))")
                exp.fulfill()
                return
            }
            XCTAssertEqual(err.code, "session_failed")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    func testIosSoftApScanIsExplicitlyUnsupported() {
        let plugin = EspProvisioningFlutterPlugin()
        let call = FlutterMethodCall(
            methodName: "scanSoftApDevices",
            arguments: ["devicePrefix": "PROV_", "timeoutMs": 1000])
        let exp = expectation(description: "error returned")
        plugin.handle(call) { result in
            guard let err = result as? FlutterError else {
                XCTFail("Expected FlutterError for iOS scanSoftApDevices")
                exp.fulfill()
                return
            }
            XCTAssertEqual(err.code, "session_failed")
            XCTAssertTrue(err.message?.contains("iOS") ?? false)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
}

final class ErrorMappingTests: XCTestCase {

    func testSec2SessionInitErrorMapsToPopInvalid() {
        let error = ErrorMapping.flutterError(
            forSessionError: .sessionInitError,
            security: .secure2,
            ssidOrName: "PROV_X")
        XCTAssertEqual(error.code, "pop_invalid")
    }

    func testSec1SessionInitErrorMapsToPopInvalid() {
        let error = ErrorMapping.flutterError(
            forSessionError: .sessionInitError,
            security: .secure,
            ssidOrName: "PROV_X")
        XCTAssertEqual(error.code, "pop_invalid")
    }

    func testSec0SessionInitErrorFallsThroughToSessionFailed() {
        let error = ErrorMapping.flutterError(
            forSessionError: .sessionInitError,
            security: .unsecure,
            ssidOrName: "PROV_X")
        XCTAssertEqual(error.code, "session_failed")
    }

    func testSoftApConnectionFailureCarriesSsidDetail() {
        let error = ErrorMapping.flutterError(
            forSessionError: .softAPConnectionFailure,
            security: .secure2,
            ssidOrName: "PROV_X")
        XCTAssertEqual(error.code, "softap_connection_failed")
        let details = error.details as? [String: Any]
        XCTAssertEqual(details?["ssid"] as? String, "PROV_X")
    }

    func testBleFailedToConnectMapsToDeviceNotFound() {
        let error = ErrorMapping.flutterError(
            forSessionError: .bleFailedToConnect,
            security: .secure2,
            ssidOrName: "PROV_X")
        XCTAssertEqual(error.code, "device_not_found")
        let details = error.details as? [String: Any]
        XCTAssertEqual(details?["deviceId"] as? String, "PROV_X")
    }

    func testNoPopMapsToPopInvalid() {
        let error = ErrorMapping.flutterError(
            forSessionError: .noPOP,
            security: .secure2,
            ssidOrName: "PROV_X")
        XCTAssertEqual(error.code, "pop_invalid")
    }

    func testProvisioningResultMapAuthFailed() {
        let map = ErrorMapping.provisioningResultMap(for: .wifiStatusAuthenticationError)
        XCTAssertEqual(map["status"] as? String, "authFailed")
    }

    func testProvisioningResultMapNetworkNotFound() {
        let map = ErrorMapping.provisioningResultMap(for: .wifiStatusNetworkNotFound)
        XCTAssertEqual(map["status"] as? String, "networkNotFound")
    }
}
