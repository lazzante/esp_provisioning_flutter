import 'package:esp_provisioning_flutter/esp_provisioning_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WifiAuthMode', () {
    test('round-trips every known auth mode through protocolValue', () {
      const known = <WifiAuthMode>[
        WifiAuthMode.open,
        WifiAuthMode.wep,
        WifiAuthMode.wpaPsk,
        WifiAuthMode.wpa2Psk,
        WifiAuthMode.wpaWpa2Psk,
        WifiAuthMode.wpa2Enterprise,
        WifiAuthMode.wpa3Psk,
        WifiAuthMode.wpa2Wpa3Psk,
        WifiAuthMode.wapiPsk,
      ];
      for (final mode in known) {
        expect(
          WifiAuthMode.fromProtocolValue(mode.protocolValue),
          mode,
          reason: 'round-trip failed for $mode',
        );
      }
    });

    test('unknown protocol values decay to .unknown', () {
      expect(WifiAuthMode.fromProtocolValue(42), WifiAuthMode.unknown);
      expect(WifiAuthMode.fromProtocolValue(-7), WifiAuthMode.unknown);
    });

    test('.unknown protocolValue is the sentinel -1', () {
      expect(WifiAuthMode.unknown.protocolValue, -1);
    });
  });

  group('WifiNetwork', () {
    test('toMap / fromMap round-trips losslessly', () {
      const network = WifiNetwork(
        ssid: 'mynet',
        rssi: -60,
        authMode: WifiAuthMode.wpa2Psk,
        channel: 6,
        bssid: 'ab:cd:ef:01:02:03',
      );
      final decoded = WifiNetwork.fromMap(network.toMap());
      expect(decoded, network);
      expect(decoded.rssi, -60);
      expect(decoded.channel, 6);
    });

    test('fromMap throws on missing ssid', () {
      expect(
        () => WifiNetwork.fromMap(<Object?, Object?>{
          'rssi': -50,
          'authMode': 3,
        }),
        throwsFormatException,
      );
    });

    test('fromMap throws on missing rssi', () {
      expect(
        () => WifiNetwork.fromMap(<Object?, Object?>{
          'ssid': 'mynet',
          'authMode': 3,
        }),
        throwsFormatException,
      );
    });

    test('fromMap throws on non-int authMode', () {
      expect(
        () => WifiNetwork.fromMap(<Object?, Object?>{
          'ssid': 'mynet',
          'rssi': -50,
          'authMode': 'wpa2',
        }),
        throwsFormatException,
      );
    });

    test('isOpen reflects open auth mode', () {
      const open = WifiNetwork(
        ssid: 'cafe',
        rssi: -40,
        authMode: WifiAuthMode.open,
      );
      const wpa = WifiNetwork(
        ssid: 'home',
        rssi: -55,
        authMode: WifiAuthMode.wpa2Psk,
      );
      expect(open.isOpen, isTrue);
      expect(wpa.isOpen, isFalse);
    });

    test('equality keys on ssid + bssid + authMode', () {
      const a = WifiNetwork(
        ssid: 'home',
        rssi: -50,
        authMode: WifiAuthMode.wpa2Psk,
        bssid: 'aa:bb:cc',
      );
      const b = WifiNetwork(
        ssid: 'home',
        rssi: -80,
        authMode: WifiAuthMode.wpa2Psk,
        bssid: 'aa:bb:cc',
      );
      expect(a, equals(b));
    });

    test('hidden SSID empty string is tolerated', () {
      final hidden = WifiNetwork.fromMap(<Object?, Object?>{
        'ssid': '',
        'rssi': -70,
        'authMode': 0,
      });
      expect(hidden.ssid, isEmpty);
      expect(hidden.authMode, WifiAuthMode.open);
    });
  });
}
