# esp_provisioning_flutter

[![pub package](https://img.shields.io/pub/v/esp_provisioning_flutter.svg)](https://pub.dev/packages/esp_provisioning_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A Flutter plugin for provisioning Espressif **ESP32** devices over **BLE** or
**SoftAP**, wrapping the official Espressif SDKs:

- iOS — [`ESPProvision`](https://github.com/espressif/esp-idf-provisioning-ios) (CocoaPod)
- Android — [`esp-idf-provisioning-android`](https://github.com/espressif/esp-idf-provisioning-android) (JitPack)

The native SDKs implement the full ESP-IDF unified provisioning protocol
(SRP6a / X25519 key exchange, AES-CTR / AES-GCM session, custom data
endpoints) — this plugin is a thin Dart bridge over them with a sealed,
strictly-typed API.

> **Status: PR #2** — scaffold + Dart API surface + tests + example app.
> Native bridges are stubs and respond with `MethodNotImplemented`. iOS
> integration ships in PR #3 and Android in PR #4. Do not depend on this
> revision in production — the package is not yet published to pub.dev.

---

## Why this plugin

Espressif does not ship an official Flutter SDK. Existing community
packages have not been maintained against current ESP-IDF releases or the
SRP6a-based security2 handshake. `esp_provisioning_flutter` is a small,
opinionated, production-grade bridge designed for commercial IoT products:

- **Sealed exception hierarchy** — exhaustive `switch` over typed failure
  modes (`BleUnavailable`, `PopInvalid`, `SessionFailed`, …) instead of
  stringly-typed `PlatformException`s leaking through.
- **Federated platform interface** — fake implementations are trivial to
  drop in for widget tests.
- **Custom data channel** — `sendCustomData(endpoint:, data:)` exposes the
  ESP-IDF custom endpoint mechanism for bootstrapping device identities,
  activation tokens, or any other app-defined payload over the encrypted
  session.
- **Both transports** — BLE first, SoftAP planned for PR #5 with a unified
  API surface.

---

## Quick start

Add the plugin to `pubspec.yaml`:

```yaml
dependencies:
  esp_provisioning_flutter: ^0.0.1
```

Then provision a device:

```dart
import 'package:esp_provisioning_flutter/esp_provisioning_flutter.dart';

Future<void> provision() async {
  final esp = EspProvisioning();

  final devices = await esp.scanBleDevices(devicePrefix: 'PROV_');
  if (devices.isEmpty) return;

  await esp.connect(
    device: devices.first,
    proofOfPossession: 'abcd1234',
    security: EspSecurity.security2,
  );

  final networks = await esp.scanWifiNetworks();

  final result = await esp.provisionWifi(
    ssid: networks.first.ssid,
    passphrase: 'mypass',
  );

  if (!result.isSuccess) {
    // Surface result.status to the user — wrong passphrase, network not
    // found, etc. Each status is documented on ProvisioningStatus.
    return;
  }

  await esp.disconnect();
}
```

---

## Error handling

Every method throws subtypes of `EspProvisioningException`. The class is
`sealed` (Dart 3) so the analyser will flag any non-exhaustive `switch`:

```dart
try {
  await esp.connect(device: device, proofOfPossession: pop);
} on EspProvisioningException catch (e) {
  switch (e) {
    case BleUnavailableException():
      // Prompt user to enable Bluetooth.
    case PermissionDeniedException(:final permission):
      // Route user to system settings for `permission`.
    case DeviceNotFoundException(:final deviceId):
      // Suggest re-scanning.
    case PopInvalidException():
      // Re-prompt for the device PoP.
    case SessionFailedException():
    case WifiProvisioningFailedException():
    case SoftApConnectionException():
      // Log + show a generic retry button.
  }
}
```

---

## Platform setup

### iOS

Add the following keys to `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>We use Bluetooth to set up your device.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>We use the local network to talk to your device while it joins your Wi-Fi.</string>
```

Minimum iOS deployment target: **13.0** (required by ESPProvision).

### Android

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
  android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"
  android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
<uses-permission android:name="android.permission.INTERNET" />
```

Minimum Android SDK: **21**. Target SDK: **34+** recommended.

You must obtain `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` (Android 12+) or
`ACCESS_FINE_LOCATION` (Android 11 and earlier) at runtime **before**
calling `scanBleDevices()`. The plugin throws `PermissionDeniedException`
when permissions are missing — it intentionally does not prompt itself, so
that your app controls prompt timing and rationale UI.

---

## API reference

| Method | Purpose |
|---|---|
| `scanBleDevices({devicePrefix, timeout})` | Discover devices advertising in BLE provisioning mode. |
| `stopBleScan()` | Cancel an in-flight scan. |
| `connect({device, proofOfPossession, security})` | Open authenticated, encrypted session. |
| `scanWifiNetworks()` | Ask the device for the Wi-Fi networks it can see. |
| `provisionWifi({ssid, passphrase})` | Send credentials, await apply result. |
| `sendCustomData({endpoint, data})` | Exchange arbitrary bytes on a custom ESP-IDF endpoint. |
| `disconnect()` | Tear down the session. |
| `events` | Broadcast stream of lifecycle phase transitions. |

Full per-method documentation is generated by `dart doc` and published with
each release; refer to the inline dartdoc on `EspProvisioning` for the
authoritative contract.

---

## Roadmap

| PR | Scope |
|---|---|
| **#2 (this PR)** | Plugin scaffold, Dart API, sealed exceptions, unit tests, example app skeleton |
| #3 | iOS native bridge — wire ESPProvision Pod into the Swift handlers |
| #4 | Android native bridge — wire `esp-idf-provisioning-android` library into Kotlin handlers |
| #5 | SoftAP fallback transport (BLE + SoftAP unified API) |
| #6 | Integration tests + example app polish + pub.dev publication |

---

## License

MIT — see [LICENSE](LICENSE). The native Espressif SDKs are licensed under
Apache-2.0 by Espressif Systems.
