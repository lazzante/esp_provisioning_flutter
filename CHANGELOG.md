# Changelog

All notable changes to `esp_provisioning_flutter` will be documented in this
file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added (PR #6 — Native unit tests + example polish + pub.dev prep)

- iOS XCTest target wired with 12 unit tests covering plugin smoke
  paths, the iOS SoftAP "explicitly unsupported" contract, and the
  full security-aware `ErrorMapping` table (sec2/sec1/sec0 connect
  failure dispatch, softap_connection_failed ssid detail,
  bleFailedToConnect → device_not_found, AUTH_FAILED /
  NETWORK_NOT_FOUND in-band result maps). All pass on the iPhone 16
  Pro simulator.
- Android JVM tests (11) mirror the iOS suite for the Kotlin
  `ErrorMapping` plus a plugin construction smoke test. Run via
  `./gradlew :esp_provisioning_flutter:testDebugUnitTest` from the
  example project.
- Example app gains: live `EspProvisioningPhase` chip beside the
  status line, dismissable error banner showing the sealed
  exception code + message, transport-aware Cancel button next to
  the Scan action (uses `stopBleScan`).
- README adds a migration guide for users of the community
  `flutter_esp_ble_prov` package, a SoftAP-per-platform behaviour
  table, and pub-score / platform badges.
- Version bumped to 0.0.5 (PR #2 → 0.0.1, PR #3 → iOS bridge,
  PR #4 → Android bridge, PR #5 → SoftAP, PR #6 → tests + polish).
  1.0.0 stabilises after pilot-batch real-device verification.

### Added (PR #5 — SoftAP fallback transport)

- New `EspProvisioning.scanSoftApDevices({devicePrefix, timeout})` for
  enumerating ESP32 devices broadcasting as Wi-Fi access points.
  Android dispatches to the SDK's `searchWiFiEspDevices`; iOS returns a
  typed `SessionFailedException` because Apple does not expose
  programmatic Wi-Fi enumeration.
- New `softApPassphrase` parameter on `connect()` — the password of the
  device's provisioning SoftAP (often empty for ESP-IDF stock firmware).
  Ignored for BLE devices.
- iOS bridge now routes `device.transport == softAp` through
  `ESPDevice(transport: .softap, ...)` + `NEHotspotConfiguration`, with
  the user accepting the system prompt to join the device's AP.
- Android bridge routes `device.transport == softAp` through
  `createESPDevice(TRANSPORT_SOFTAP, ...) → connectWiFiDevice(ssid, password)`.
- Example app gets a `SegmentedButton` transport selector + a manual
  SSID entry for iOS SoftAP flows.
- README documents per-platform SoftAP capabilities and code snippets
  for both flows.

### Added (PR #4 — Android native bridge)

- Pinned `com.github.espressif:esp-idf-provisioning-android:lib-2.4.4`
  via JitPack; added JitPack repository to plugin + example app gradle.
- `ProvisioningBridge.kt` wraps the SDK behind a single per-plugin state
  machine: scan cache (BluetoothDevice + primary service UUID + advertised
  name + RSSI keyed by MAC), in-flight scan + connect guards, EventBus
  subscription for `DeviceConnectionEvent`, main-thread marshalling of
  every callback, defensive scan timer fallback for OEM Android skins
  whose `BleScanListener.scanCompleted` is unreliable.
- `BluetoothStateProbe.kt` checks `BluetoothAdapter` power state and
  runtime permission state (`BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` on
  API 31+, `ACCESS_FINE_LOCATION` below) before scanning, so callers
  receive typed `ble_unavailable` / `permission_denied` instead of a
  generic "no device found".
- `ErrorMapping.kt` mirrors the Swift error mapping: security-aware
  connect failures (`SECURITY_1`/`SECURITY_2` → `pop_invalid`),
  AUTH_FAILED / NETWORK_NOT_FOUND in-band as `ProvisioningResult`,
  channel collapse as `wifi_provisioning_failed`, unknown errors →
  `session_failed`.
- Custom data path (`sendDataToCustomEndPoint`) supports RainyBit
  bootstrap-token transfer over the encrypted session.
- Plugin AndroidManifest declares `BLUETOOTH_SCAN` /
  `BLUETOOTH_CONNECT` (Android 12+, `neverForLocation`),
  `ACCESS_FINE_LOCATION` (maxSdkVersion 30), and the SoftAP-adjacent
  Wi-Fi / network permissions for PR #5.
- Example app manifest carries the same permission set; plugin minSdk
  bumped to 23 for runtime-permission flow parity with rainybit_mobile.
- README documents the JitPack repo requirement for consuming apps.

### Added (PR #3 — iOS native bridge)

- Pinned `ESPProvision` ~> 3.1 in the podspec.
- `ProvisioningBridge.swift` wraps the ESPProvision SDK behind a single
  per-plugin state machine: discovered-device cache, in-flight scan +
  connect guards, lifecycle event emission, and main-queue marshalling
  of every callback.
- `BluetoothStateProbe.swift` resolves Core Bluetooth state before the
  first scan so callers receive a typed `BleUnavailableException` or
  `PermissionDeniedException` instead of a generic "no device found".
- `ErrorMapping.swift` translates ESPSessionError / ESPWiFiScanError /
  ESPProvisionError into the sealed Dart exception vocabulary, with
  security-level-aware handling of `sessionInitError` (wrong PoP under
  sec1/sec2 → `pop_invalid`).
- Wires every method-channel call (`scanBleDevices`, `stopBleScan`,
  `connect`, `scanWifiNetworks`, `provisionWifi`, `sendCustomData`,
  `disconnect`) to real SDK invocations.
- Custom data path (`sendCustomData`) supports RainyBit bootstrap-token
  transfer over the encrypted session.
- Lifecycle events for every phase: scanStarted/Finished, connecting,
  sessionEstablishing/Established, wifiScanning, applyingCredentials,
  finished, disconnected.
- Example app `Info.plist` carries the required Bluetooth / local-network
  usage descriptions; Podfile pins `platform :ios, '13.0'`.

## 0.0.1 - 2026-05-14

### Added

- Initial plugin scaffold (`flutter create --template=plugin`, org
  `com.rainybit`, platforms `android`/`ios`).
- Federated platform interface (`EspProvisioningPlatform`) and default
  method-channel implementation (`MethodChannelEspProvisioning`).
- High-level facade `EspProvisioning` with:
  - `scanBleDevices`, `stopBleScan`
  - `connect` (PoP + `EspSecurity` selection)
  - `scanWifiNetworks`
  - `provisionWifi`
  - `sendCustomData` (arbitrary bytes over the secure session)
  - `disconnect`
  - `events` lifecycle stream
- Sealed exception hierarchy: `BleUnavailableException`,
  `PermissionDeniedException`, `DeviceNotFoundException`,
  `PopInvalidException`, `SessionFailedException`,
  `WifiProvisioningFailedException`, `SoftApConnectionException`.
- Sealed transport hierarchy (`BleTransport`, `SoftApTransport`) with
  method-channel round-trip serialisation.
- Models: `EspDevice`, `WifiNetwork`, `ProvisioningResult`,
  `EspProvisioningEvent`, `EspSecurity`.
- Native plugin stubs (Swift + Kotlin) registering both the methods and
  events channels; all method handlers respond with
  `MethodNotImplemented` pending PR #3 (iOS) and PR #4 (Android).
- Example app with a button-driven scan → connect → Wi-Fi scan → provision
  flow.
- Unit test suite covering model serialisation, transport parsing,
  exception mapping, and platform interface contracts.
