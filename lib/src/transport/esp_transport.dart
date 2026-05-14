import 'package:meta/meta.dart';

/// Sealed base type for ESP32 provisioning transports.
///
/// A transport describes *how* the mobile client should reach the device:
///   * [BleTransport] — open a GATT connection to a BLE-advertised peripheral
///     and run the provisioning protocol over BLE characteristics.
///   * [SoftApTransport] — associate with the Wi-Fi access point the device
///     hosts in its provisioning mode, then exchange provisioning frames
///     over HTTP-on-Wi-Fi.
///
/// Both modes are supported by ESP-IDF's `wifi_provisioning_manager`; the
/// transport choice is dictated by how the firmware was configured. Calling
/// code does not normally construct these instances directly — they are
/// derived from the [EspDevice] picked out of a scan list — but the type
/// is exposed so applications that pre-configure their fleet can build a
/// transport descriptor without performing a scan first.
@immutable
sealed class EspTransport {
  /// Initialises the common identity portion of the transport.
  const EspTransport({required this.deviceId});

  /// The identifier the transport will route to. Format is transport
  /// specific — peripheral UUID / MAC for BLE, SSID for SoftAP.
  final String deviceId;

  /// A stable string tag used on the method-channel wire format to identify
  /// which transport variant a map represents. Avoids relying on Dart's
  /// `runtimeType` over the channel boundary.
  String get kind;

  /// Encodes this transport as a method-channel-safe map. Round-trips with
  /// [EspTransport.fromMap].
  Map<String, Object?> toMap();

  /// Decodes the appropriate concrete transport from a method-channel map.
  /// Throws [FormatException] if the map is missing the discriminator or
  /// contains an unknown [kind].
  factory EspTransport.fromMap(Map<Object?, Object?> map) {
    final kind = map['kind'];
    if (kind is! String) {
      throw const FormatException(
        'EspTransport.fromMap: missing/invalid "kind" discriminator',
      );
    }
    switch (kind) {
      case 'ble':
        return BleTransport.fromMap(map);
      case 'softAp':
      case 'softap':
        return SoftApTransport.fromMap(map);
      default:
        throw FormatException('Unknown EspTransport kind: $kind');
    }
  }
}

/// Transport that connects to the device over Bluetooth Low Energy GATT.
///
/// The optional [primaryServiceUuid] hint is forwarded to the native SDK to
/// short-circuit scanning when the firmware is known to advertise a specific
/// 128-bit service UUID — improves connection latency on devices that bury
/// the provisioning service behind multiple secondary services.
final class BleTransport extends EspTransport {
  /// Creates a BLE transport descriptor.
  const BleTransport({
    required super.deviceId,
    this.primaryServiceUuid,
  });

  /// The advertised primary service UUID, if known. When `null` the native
  /// side falls back to the ESPProvision / `esp-idf-provisioning-android`
  /// default service discovery.
  final String? primaryServiceUuid;

  @override
  String get kind => 'ble';

  @override
  Map<String, Object?> toMap() => <String, Object?>{
    'kind': kind,
    'deviceId': deviceId,
    'primaryServiceUuid': primaryServiceUuid,
  };

  /// Decodes a [BleTransport] from a method-channel map.
  factory BleTransport.fromMap(Map<Object?, Object?> map) {
    final deviceId = map['deviceId'];
    if (deviceId is! String || deviceId.isEmpty) {
      throw const FormatException(
        'BleTransport.fromMap: missing/invalid "deviceId"',
      );
    }
    final svc = map['primaryServiceUuid'];
    if (svc != null && svc is! String) {
      throw const FormatException(
        'BleTransport.fromMap: "primaryServiceUuid" must be String',
      );
    }
    return BleTransport(
      deviceId: deviceId,
      primaryServiceUuid: svc as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BleTransport &&
      other.deviceId == deviceId &&
      other.primaryServiceUuid == primaryServiceUuid;

  @override
  int get hashCode => Object.hash(deviceId, primaryServiceUuid);

  @override
  String toString() =>
      'BleTransport(deviceId: $deviceId, primaryServiceUuid: $primaryServiceUuid)';
}

/// Transport that associates with the device's provisioning Wi-Fi SoftAP and
/// runs the protocol over HTTP-on-Wi-Fi.
///
/// SoftAP is typically used as a fallback when BLE is unavailable (older
/// ESP32 silicon, host phones with broken BLE stacks). The native plugins
/// handle the OS-specific Wi-Fi association dance — the caller only needs to
/// supply the SSID and, if the firmware sets one, the passphrase.
final class SoftApTransport extends EspTransport {
  /// Creates a SoftAP transport descriptor. The [deviceId] doubles as the
  /// SSID the device advertises.
  const SoftApTransport({
    required super.deviceId,
    this.passphrase,
    this.endpointBaseUrl,
  });

  /// The passphrase for the SoftAP, or `null` for open networks. ESP-IDF
  /// defaults to open SoftAPs for provisioning but production firmware
  /// often sets a passphrase to limit who can attempt to join.
  final String? passphrase;

  /// Optional override of the HTTP base URL the native plugin uses once
  /// associated. Defaults to `http://192.168.4.1` (ESP-IDF stock) on the
  /// native side when `null`.
  final String? endpointBaseUrl;

  @override
  String get kind => 'softAp';

  @override
  Map<String, Object?> toMap() => <String, Object?>{
    'kind': kind,
    'deviceId': deviceId,
    'passphrase': passphrase,
    'endpointBaseUrl': endpointBaseUrl,
  };

  /// Decodes a [SoftApTransport] from a method-channel map.
  factory SoftApTransport.fromMap(Map<Object?, Object?> map) {
    final deviceId = map['deviceId'];
    if (deviceId is! String || deviceId.isEmpty) {
      throw const FormatException(
        'SoftApTransport.fromMap: missing/invalid "deviceId"',
      );
    }
    final passphrase = map['passphrase'];
    if (passphrase != null && passphrase is! String) {
      throw const FormatException(
        'SoftApTransport.fromMap: "passphrase" must be String',
      );
    }
    final endpointBaseUrl = map['endpointBaseUrl'];
    if (endpointBaseUrl != null && endpointBaseUrl is! String) {
      throw const FormatException(
        'SoftApTransport.fromMap: "endpointBaseUrl" must be String',
      );
    }
    return SoftApTransport(
      deviceId: deviceId,
      passphrase: passphrase as String?,
      endpointBaseUrl: endpointBaseUrl as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SoftApTransport &&
      other.deviceId == deviceId &&
      other.passphrase == passphrase &&
      other.endpointBaseUrl == endpointBaseUrl;

  @override
  int get hashCode => Object.hash(deviceId, passphrase, endpointBaseUrl);

  @override
  String toString() =>
      'SoftApTransport(deviceId: $deviceId, passphrase: ${passphrase == null ? 'null' : '***'}, '
      'endpointBaseUrl: $endpointBaseUrl)';
}
