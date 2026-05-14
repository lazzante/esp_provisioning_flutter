import 'package:meta/meta.dart';

/// The transport over which an [EspDevice] advertises itself.
///
/// ESP32 provisioning supports two transports — BLE GATT and SoftAP (a Wi-Fi
/// access point exposed by the device). A discovered device descriptor records
/// which transport was used to find it so that the same transport can later be
/// used to open a session.
enum EspDeviceTransport {
  /// Bluetooth Low Energy GATT transport.
  ble,

  /// Wi-Fi SoftAP transport (the device hosts an open or WPA2 access point and
  /// serves HTTP-over-Wi-Fi provisioning endpoints).
  softAp,
}

/// A descriptor for an ESP32 device discovered during provisioning scan.
///
/// Instances are produced by [EspProvisioning.scanBleDevices] (and the upcoming
/// SoftAP scan) and consumed by [EspProvisioning.connect]. The descriptor
/// carries the minimum information required to re-identify the device on the
/// native side — for BLE this is the advertised name plus the SoC's BLE service
/// UUID; for SoftAP it is the SSID and an optional BSSID.
///
/// Instances are immutable and implement value-equality on [id] + [transport].
@immutable
class EspDevice {
  /// Creates a descriptor. Prefer the named constructors [EspDevice.ble] and
  /// [EspDevice.softAp] from application code — the public constructor is
  /// retained for platform implementations that decode the wire format.
  const EspDevice({
    required this.id,
    required this.name,
    required this.transport,
    this.rssi,
    this.serviceUuid,
    this.bssid,
  });

  /// Convenience constructor for a BLE-advertised device.
  const EspDevice.ble({
    required String id,
    required String name,
    int? rssi,
    String? serviceUuid,
  }) : this(
         id: id,
         name: name,
         transport: EspDeviceTransport.ble,
         rssi: rssi,
         serviceUuid: serviceUuid,
       );

  /// Convenience constructor for a SoftAP device.
  const EspDevice.softAp({
    required String id,
    required String name,
    int? rssi,
    String? bssid,
  }) : this(
         id: id,
         name: name,
         transport: EspDeviceTransport.softAp,
         rssi: rssi,
         bssid: bssid,
       );

  /// A stable, transport-specific identifier for this device.
  ///
  /// For [EspDeviceTransport.ble] this is typically the platform peripheral
  /// identifier (a UUID on iOS, a MAC address on Android). For
  /// [EspDeviceTransport.softAp] this is the SSID.
  final String id;

  /// The human-readable device name, e.g. `PROV_AB12CD`.
  final String name;

  /// Which transport this device was discovered over.
  final EspDeviceTransport transport;

  /// Received Signal Strength Indicator, in dBm, at the time of discovery.
  /// `null` if the platform did not report it.
  final int? rssi;

  /// The BLE primary service UUID advertised by the device, if any. Only
  /// meaningful for BLE-discovered devices.
  final String? serviceUuid;

  /// The BSSID of the SoftAP, if reported by the platform. Only meaningful for
  /// SoftAP-discovered devices.
  final String? bssid;

  /// Decodes an [EspDevice] from the platform-channel map representation.
  ///
  /// The map shape mirrors what the native plugins send across the method
  /// channel. Throws [FormatException] if a required field is missing or has
  /// the wrong type.
  factory EspDevice.fromMap(Map<Object?, Object?> map) {
    final id = map['id'];
    final name = map['name'];
    final transportRaw = map['transport'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('EspDevice.fromMap: missing/invalid "id"');
    }
    if (name is! String) {
      throw const FormatException('EspDevice.fromMap: missing/invalid "name"');
    }
    if (transportRaw is! String) {
      throw const FormatException(
        'EspDevice.fromMap: missing/invalid "transport"',
      );
    }
    final transport = _parseTransport(transportRaw);
    final rssiRaw = map['rssi'];
    if (rssiRaw != null && rssiRaw is! int) {
      throw const FormatException('EspDevice.fromMap: "rssi" must be int');
    }
    final serviceUuid = map['serviceUuid'];
    if (serviceUuid != null && serviceUuid is! String) {
      throw const FormatException(
        'EspDevice.fromMap: "serviceUuid" must be String',
      );
    }
    final bssid = map['bssid'];
    if (bssid != null && bssid is! String) {
      throw const FormatException('EspDevice.fromMap: "bssid" must be String');
    }
    return EspDevice(
      id: id,
      name: name,
      transport: transport,
      rssi: rssiRaw as int?,
      serviceUuid: serviceUuid as String?,
      bssid: bssid as String?,
    );
  }

  /// Encodes this descriptor as a method-channel-safe map.
  ///
  /// Used internally to pass the device back to the native side when opening a
  /// session. Round-trips losslessly with [EspDevice.fromMap].
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'transport': _encodeTransport(transport),
      'rssi': rssi,
      'serviceUuid': serviceUuid,
      'bssid': bssid,
    };
  }

  /// Returns a copy of this descriptor with selected fields overridden.
  EspDevice copyWith({
    String? id,
    String? name,
    EspDeviceTransport? transport,
    int? rssi,
    String? serviceUuid,
    String? bssid,
  }) {
    return EspDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      transport: transport ?? this.transport,
      rssi: rssi ?? this.rssi,
      serviceUuid: serviceUuid ?? this.serviceUuid,
      bssid: bssid ?? this.bssid,
    );
  }

  static EspDeviceTransport _parseTransport(String raw) {
    switch (raw) {
      case 'ble':
        return EspDeviceTransport.ble;
      case 'softAp':
      case 'softap':
        return EspDeviceTransport.softAp;
      default:
        throw FormatException('Unknown EspDeviceTransport: $raw');
    }
  }

  static String _encodeTransport(EspDeviceTransport transport) {
    switch (transport) {
      case EspDeviceTransport.ble:
        return 'ble';
      case EspDeviceTransport.softAp:
        return 'softAp';
    }
  }

  @override
  bool operator ==(Object other) {
    return other is EspDevice && other.id == id && other.transport == transport;
  }

  @override
  int get hashCode => Object.hash(id, transport);

  @override
  String toString() =>
      'EspDevice(id: $id, name: $name, transport: $transport, '
      'rssi: $rssi, serviceUuid: $serviceUuid, bssid: $bssid)';
}
