import 'dart:async';
import 'dart:typed_data';

import 'esp_provisioning_platform.dart';
import 'models/esp_device.dart';
import 'models/esp_provisioning_event.dart';
import 'models/esp_security.dart';
import 'models/provisioning_result.dart';
import 'models/wifi_network.dart';

/// High-level entry point for provisioning ESP32 devices over BLE or SoftAP.
///
/// [EspProvisioning] is a thin facade over [EspProvisioningPlatform.instance].
/// It exists so that application code has a single, ergonomic class to reach
/// for, while the federated platform interface remains available for plugin
/// authors and tests that want to substitute a fake implementation.
///
/// ### Lifecycle
///
/// A typical provisioning flow looks like this:
///
/// ```dart
/// final esp = EspProvisioning();
///
/// // 1. Discover devices broadcasting in provisioning mode.
/// final devices = await esp.scanBleDevices(devicePrefix: 'PROV_');
///
/// // 2. Open a secure session with a known PoP.
/// await esp.connect(
///   device: devices.first,
///   proofOfPossession: 'abcd1234',
/// );
///
/// // 3. Show the user the networks the device can see.
/// final networks = await esp.scanWifiNetworks();
///
/// // 4. Send credentials.
/// final result = await esp.provisionWifi(
///   ssid: networks.first.ssid,
///   passphrase: '••••••••',
/// );
///
/// // 5. Optionally exchange application-defined data.
/// final token = Uint8List.fromList(utf8.encode('hello'));
/// final reply = await esp.sendCustomData(
///   endpoint: 'rainybit-bootstrap',
///   data: token,
/// );
///
/// // 6. Tear down.
/// await esp.disconnect();
/// ```
///
/// ### Error handling
///
/// All methods throw subtypes of [EspProvisioningException] on failure. The
/// hierarchy is sealed, so callers can write exhaustive `switch` expressions
/// to handle each failure mode.
///
/// ### Thread / isolate safety
///
/// All methods on this class must be invoked from the Flutter UI isolate —
/// the underlying method channel is bound to that isolate. The same
/// [EspProvisioning] instance can be reused across many provisioning
/// sessions, but only one session may be open at a time.
class EspProvisioning {
  /// Creates a facade backed by the current [EspProvisioningPlatform.instance].
  EspProvisioning();

  EspProvisioningPlatform get _platform => EspProvisioningPlatform.instance;

  /// Scans for ESP32 devices advertising in BLE provisioning mode.
  ///
  /// Only advertisements whose local name starts with [devicePrefix] are
  /// returned. ESP-IDF defaults this prefix to `PROV_` but firmware can
  /// override it; pass whatever value the device team configured.
  ///
  /// The scan runs until [timeout] elapses (default 10 seconds) or until the
  /// host OS terminates it for power reasons — Android in particular caps
  /// background BLE scans at 30 seconds in some OEM builds.
  ///
  /// Returns the deduplicated list of devices observed during the scan
  /// window. The list may be empty.
  ///
  /// Throws:
  ///   * [BleUnavailableException] — Bluetooth is off or unsupported.
  ///   * [PermissionDeniedException] — scan/connect permissions denied.
  Future<List<EspDevice>> scanBleDevices({
    required String devicePrefix,
    Duration timeout = const Duration(seconds: 10),
  }) {
    return _platform.scanBleDevices(
      devicePrefix: devicePrefix,
      timeout: timeout,
    );
  }

  /// Stops an in-flight BLE scan immediately. No-op when no scan is running.
  Future<void> stopBleScan() => _platform.stopBleScan();

  /// Connects to [device] and establishes an authenticated, encrypted
  /// provisioning session.
  ///
  /// The session is authenticated using [proofOfPossession] — a shared
  /// secret printed on the device sticker or QR code. The native SDK runs
  /// the [security] handshake (default [EspSecurity.security2], SRP6a +
  /// AES-GCM) and stores the resulting session key for subsequent calls.
  ///
  /// Throws:
  ///   * [DeviceNotFoundException] — device is out of range or already
  ///     connected to another central.
  ///   * [PopInvalidException] — PoP rejected by the device firmware.
  ///   * [SessionFailedException] — handshake failure not attributable to a
  ///     wrong PoP (transport drop, protocol mismatch).
  Future<void> connect({
    required EspDevice device,
    required String proofOfPossession,
    EspSecurity security = EspSecurity.security2,
  }) {
    return _platform.connect(
      device: device,
      proofOfPossession: proofOfPossession,
      security: security,
    );
  }

  /// Asks the connected device to scan for Wi-Fi networks visible to it and
  /// return the results.
  ///
  /// The list is sorted by signal strength (strongest first) by the native
  /// SDK; callers may resort or filter as they wish (e.g. hiding 5 GHz
  /// entries on ESP32 classic).
  ///
  /// Throws [SessionFailedException] if no session is open.
  Future<List<WifiNetwork>> scanWifiNetworks() => _platform.scanWifiNetworks();

  /// Sends Wi-Fi credentials to the device and awaits its apply verdict.
  ///
  /// Note that a non-success verdict is **not** thrown as an exception — it
  /// is returned as a [ProvisioningResult] with a non-success status, so
  /// callers can re-prompt the user for a corrected passphrase without
  /// special-casing exceptions. See [ProvisioningResult] for the exhaustive
  /// list of outcomes.
  ///
  /// Throws:
  ///   * [WifiProvisioningFailedException] — channel collapsed before the
  ///     device reported a verdict.
  Future<ProvisioningResult> provisionWifi({
    required String ssid,
    required String passphrase,
  }) {
    return _platform.provisionWifi(ssid: ssid, passphrase: passphrase);
  }

  /// Sends application-defined bytes over the secure provisioning channel
  /// to a custom endpoint registered by the device firmware.
  ///
  /// The most common use of this is one-time bootstrapping of a device
  /// identity or activation token without exposing it over the public Wi-Fi
  /// network — the secure session encrypts the payload end-to-end.
  ///
  /// The [endpoint] must be registered on the device via
  /// `wifi_prov_mgr_endpoint_create` and `wifi_prov_mgr_endpoint_register`
  /// before the session is opened. The device's response is returned as a
  /// raw byte buffer; the schema is entirely application-defined.
  Future<Uint8List> sendCustomData({
    required String endpoint,
    required Uint8List data,
  }) {
    return _platform.sendCustomData(endpoint: endpoint, data: data);
  }

  /// Tears down the active provisioning session, closing the BLE
  /// connection or disassociating from the SoftAP as appropriate.
  ///
  /// Safe to call when no session is open — the call resolves successfully
  /// without side effects.
  Future<void> disconnect() => _platform.disconnect();

  /// A broadcast stream of [EspProvisioningEvent]s describing the plugin's
  /// internal lifecycle progress. Subscribers may attach and detach at any
  /// time; events are not buffered, so a listener attached after a phase
  /// transition does not receive a replay of earlier events.
  Stream<EspProvisioningEvent> get events => _platform.events;
}
