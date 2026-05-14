# Changelog

All notable changes to `esp_provisioning_flutter` will be documented in this
file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
