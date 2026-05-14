import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_esp_provisioning.dart';
import 'models/esp_device.dart';
import 'models/esp_provisioning_event.dart';
import 'models/esp_security.dart';
import 'models/provisioning_result.dart';
import 'models/wifi_network.dart';

/// The federated platform interface for `esp_provisioning_flutter`.
///
/// Federated Flutter plugins separate the Dart-facing API (in this package)
/// from per-platform implementations. The default implementation, backed by
/// a [MethodChannel], lives in [MethodChannelEspProvisioning]. Alternative
/// implementations — for example a fake used in widget tests, or a future
/// `*_linux` package — register themselves by assigning to
/// [EspProvisioningPlatform.instance].
///
/// Direct callers should use the [EspProvisioning] facade rather than this
/// interface; the interface is documented for plugin authors who need to
/// substitute or extend the platform implementation.
abstract base class EspProvisioningPlatform extends PlatformInterface {
  /// Constructs the base class and registers the verification token.
  EspProvisioningPlatform() : super(token: _token);

  static final Object _token = Object();

  static EspProvisioningPlatform _instance = MethodChannelEspProvisioning();

  /// The currently-installed platform implementation. Reads return the
  /// default [MethodChannelEspProvisioning] unless a different
  /// implementation has registered itself.
  static EspProvisioningPlatform get instance => _instance;

  /// Registers an alternative platform implementation. The runtime verifies
  /// that [instance] was constructed against this package's token, so an
  /// arbitrary class cannot accidentally replace the platform — this is the
  /// standard plugin_platform_interface guard.
  static set instance(EspProvisioningPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Scans for ESP32 devices advertising in provisioning mode over BLE.
  ///
  /// Implementations must filter the scan results by [devicePrefix] and
  /// resolve the future no later than [timeout]. See
  /// [EspProvisioning.scanBleDevices] for full semantics.
  Future<List<EspDevice>> scanBleDevices({
    required String devicePrefix,
    required Duration timeout,
  });

  /// Stops any in-flight BLE scan. Safe to call when no scan is running.
  Future<void> stopBleScan();

  /// Connects to [device] and establishes a secure provisioning session
  /// using [proofOfPossession] and [security]. Throws an
  /// [EspProvisioningException] on failure.
  Future<void> connect({
    required EspDevice device,
    required String proofOfPossession,
    required EspSecurity security,
  });

  /// Asks the connected device to scan for Wi-Fi networks visible to it.
  Future<List<WifiNetwork>> scanWifiNetworks();

  /// Sends Wi-Fi credentials to the connected device and waits for it to
  /// report the apply result. See [ProvisioningResult] for outcome semantics.
  Future<ProvisioningResult> provisionWifi({
    required String ssid,
    required String passphrase,
  });

  /// Sends arbitrary application-defined data on the secure provisioning
  /// channel, addressed to the named [endpoint]. The endpoint must be
  /// registered on the device firmware via
  /// `wifi_prov_mgr_endpoint_create` + `..._endpoint_register`.
  Future<Uint8List> sendCustomData({
    required String endpoint,
    required Uint8List data,
  });

  /// Tears down the active provisioning session. Safe to call when no
  /// session is open.
  Future<void> disconnect();

  /// A broadcast stream of lifecycle events as the plugin progresses
  /// through scan → connect → provision phases. Subscribers may join /
  /// leave at any time.
  Stream<EspProvisioningEvent> get events;
}
