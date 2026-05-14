import 'package:meta/meta.dart';

/// The authentication / security mode advertised by a Wi-Fi access point.
///
/// These values mirror the `wifi_auth_mode_t` enum from ESP-IDF; the integer
/// ordinal returned by [protocolValue] is what the underlying ESP-IDF
/// `wifi_scan_result` payload uses. Unknown values from the native side are
/// mapped to [WifiAuthMode.unknown] rather than failing — auth-mode is purely
/// advisory to the UI and should not cause provisioning to abort.
enum WifiAuthMode {
  /// Open network — no authentication required.
  open,

  /// Legacy WEP. Deprecated; few production access points still use it.
  wep,

  /// WPA Personal (PSK).
  wpaPsk,

  /// WPA2 Personal (PSK).
  wpa2Psk,

  /// Mixed WPA/WPA2 Personal.
  wpaWpa2Psk,

  /// WPA Enterprise (EAP).
  wpa2Enterprise,

  /// WPA3 Personal (SAE).
  wpa3Psk,

  /// Mixed WPA2/WPA3 Personal.
  wpa2Wpa3Psk,

  /// WAPI (Chinese Wi-Fi standard).
  wapiPsk,

  /// Auth mode not recognised by this plugin version.
  unknown;

  /// The integer that the ESP-IDF wifi-provisioning protobufs use to identify
  /// this auth mode on the wire.
  int get protocolValue {
    switch (this) {
      case WifiAuthMode.open:
        return 0;
      case WifiAuthMode.wep:
        return 1;
      case WifiAuthMode.wpaPsk:
        return 2;
      case WifiAuthMode.wpa2Psk:
        return 3;
      case WifiAuthMode.wpaWpa2Psk:
        return 4;
      case WifiAuthMode.wpa2Enterprise:
        return 5;
      case WifiAuthMode.wpa3Psk:
        return 6;
      case WifiAuthMode.wpa2Wpa3Psk:
        return 7;
      case WifiAuthMode.wapiPsk:
        return 8;
      case WifiAuthMode.unknown:
        return -1;
    }
  }

  /// Decodes the integer used by ESP-IDF's `wifi_auth_mode_t` enum. Unknown
  /// values map to [WifiAuthMode.unknown].
  static WifiAuthMode fromProtocolValue(int value) {
    switch (value) {
      case 0:
        return WifiAuthMode.open;
      case 1:
        return WifiAuthMode.wep;
      case 2:
        return WifiAuthMode.wpaPsk;
      case 3:
        return WifiAuthMode.wpa2Psk;
      case 4:
        return WifiAuthMode.wpaWpa2Psk;
      case 5:
        return WifiAuthMode.wpa2Enterprise;
      case 6:
        return WifiAuthMode.wpa3Psk;
      case 7:
        return WifiAuthMode.wpa2Wpa3Psk;
      case 8:
        return WifiAuthMode.wapiPsk;
      default:
        return WifiAuthMode.unknown;
    }
  }
}

/// A single Wi-Fi network as observed by the ESP32 device during a Wi-Fi scan.
///
/// Returned in lists by [EspProvisioning.scanWifiNetworks]. Note that this is
/// the scan list **from the device's perspective**, not the mobile phone's:
/// the user typically wants to pick a 2.4 GHz network the ESP32 can see, which
/// may differ from what the phone sees, especially in dual-band homes.
@immutable
class WifiNetwork {
  /// Creates a Wi-Fi network descriptor.
  const WifiNetwork({
    required this.ssid,
    required this.rssi,
    required this.authMode,
    this.channel,
    this.bssid,
  });

  /// The SSID broadcast by the access point. May be the empty string for
  /// hidden networks; the underlying SDK still surfaces them.
  final String ssid;

  /// Received Signal Strength Indicator in dBm.
  final int rssi;

  /// The authentication mode the AP advertises in its beacon frames.
  final WifiAuthMode authMode;

  /// The Wi-Fi channel (1-13 for 2.4 GHz, 36+ for 5 GHz). `null` when the
  /// platform did not include it. ESP32 classic supports 2.4 GHz only; an
  /// entry with a 5 GHz channel here usually means the device's radio cannot
  /// actually connect to it and the UI should hide it.
  final int? channel;

  /// The BSSID (MAC address of the AP), if reported.
  final String? bssid;

  /// Decodes a [WifiNetwork] from the method-channel map representation.
  /// Throws [FormatException] if required fields are missing or have the
  /// wrong type.
  factory WifiNetwork.fromMap(Map<Object?, Object?> map) {
    final ssid = map['ssid'];
    final rssi = map['rssi'];
    final authModeRaw = map['authMode'];
    if (ssid is! String) {
      throw const FormatException(
        'WifiNetwork.fromMap: missing/invalid "ssid"',
      );
    }
    if (rssi is! int) {
      throw const FormatException(
        'WifiNetwork.fromMap: missing/invalid "rssi"',
      );
    }
    if (authModeRaw is! int) {
      throw const FormatException(
        'WifiNetwork.fromMap: missing/invalid "authMode"',
      );
    }
    final channelRaw = map['channel'];
    if (channelRaw != null && channelRaw is! int) {
      throw const FormatException('WifiNetwork.fromMap: "channel" must be int');
    }
    final bssid = map['bssid'];
    if (bssid != null && bssid is! String) {
      throw const FormatException('WifiNetwork.fromMap: "bssid" must be String');
    }
    return WifiNetwork(
      ssid: ssid,
      rssi: rssi,
      authMode: WifiAuthMode.fromProtocolValue(authModeRaw),
      channel: channelRaw as int?,
      bssid: bssid as String?,
    );
  }

  /// Encodes this network as a method-channel-safe map.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'ssid': ssid,
      'rssi': rssi,
      'authMode': authMode.protocolValue,
      'channel': channel,
      'bssid': bssid,
    };
  }

  /// Whether the network requires a passphrase to join.
  ///
  /// Convenience for UIs that want to disable a passphrase field when the
  /// user picks an open network.
  bool get isOpen => authMode == WifiAuthMode.open;

  @override
  bool operator ==(Object other) {
    return other is WifiNetwork &&
        other.ssid == ssid &&
        other.bssid == bssid &&
        other.authMode == authMode;
  }

  @override
  int get hashCode => Object.hash(ssid, bssid, authMode);

  @override
  String toString() =>
      'WifiNetwork(ssid: $ssid, rssi: $rssi, authMode: $authMode, '
      'channel: $channel, bssid: $bssid)';
}
