import 'package:esp_provisioning_flutter/esp_provisioning_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BleTransport', () {
    test('toMap / fromMap round-trips losslessly', () {
      const t = BleTransport(
        deviceId: 'AA:BB:CC',
        primaryServiceUuid: '021a9004-0382-4aea-bff4-6b3f1c5adfb4',
      );
      final decoded = BleTransport.fromMap(t.toMap());
      expect(decoded, t);
      expect(decoded.primaryServiceUuid, t.primaryServiceUuid);
    });

    test('fromMap throws on missing deviceId', () {
      expect(
        () =>
            BleTransport.fromMap(<Object?, Object?>{'kind': 'ble'}),
        throwsFormatException,
      );
    });

    test('fromMap rejects non-string primaryServiceUuid', () {
      expect(
        () => BleTransport.fromMap(<Object?, Object?>{
          'kind': 'ble',
          'deviceId': 'AA',
          'primaryServiceUuid': 42,
        }),
        throwsFormatException,
      );
    });
  });

  group('SoftApTransport', () {
    test('toMap / fromMap round-trips losslessly', () {
      const t = SoftApTransport(
        deviceId: 'PROV_X',
        passphrase: 'secret',
        endpointBaseUrl: 'http://192.168.4.1',
      );
      final decoded = SoftApTransport.fromMap(t.toMap());
      expect(decoded, t);
      expect(decoded.passphrase, t.passphrase);
      expect(decoded.endpointBaseUrl, t.endpointBaseUrl);
    });

    test('toString redacts the passphrase', () {
      const t = SoftApTransport(
        deviceId: 'PROV_X',
        passphrase: 'super-secret',
      );
      expect(t.toString(), isNot(contains('super-secret')));
      expect(t.toString(), contains('***'));
    });

    test('fromMap throws on missing deviceId', () {
      expect(
        () => SoftApTransport.fromMap(<Object?, Object?>{
          'kind': 'softAp',
        }),
        throwsFormatException,
      );
    });
  });

  group('EspTransport.fromMap discriminator', () {
    test('dispatches to BleTransport when kind=ble', () {
      final t = EspTransport.fromMap(<Object?, Object?>{
        'kind': 'ble',
        'deviceId': 'AA',
      });
      expect(t, isA<BleTransport>());
    });

    test('dispatches to SoftApTransport when kind=softAp', () {
      final t = EspTransport.fromMap(<Object?, Object?>{
        'kind': 'softAp',
        'deviceId': 'PROV_X',
      });
      expect(t, isA<SoftApTransport>());
    });

    test('accepts legacy softap discriminator', () {
      final t = EspTransport.fromMap(<Object?, Object?>{
        'kind': 'softap',
        'deviceId': 'PROV_X',
      });
      expect(t, isA<SoftApTransport>());
    });

    test('throws on missing discriminator', () {
      expect(
        () => EspTransport.fromMap(const <Object?, Object?>{}),
        throwsFormatException,
      );
    });

    test('throws on unknown discriminator value', () {
      expect(
        () => EspTransport.fromMap(<Object?, Object?>{
          'kind': 'lora',
          'deviceId': 'X',
        }),
        throwsFormatException,
      );
    });

    test('sealed switch is exhaustive over BleTransport + SoftApTransport', () {
      // If a future PR adds a third transport, the switch below must be
      // updated; Dart will error at compile time, catching the oversight.
      const transports = <EspTransport>[
        BleTransport(deviceId: 'AA'),
        SoftApTransport(deviceId: 'PROV_X'),
      ];
      for (final t in transports) {
        final tag = switch (t) {
          BleTransport() => 'ble',
          SoftApTransport() => 'softAp',
        };
        expect(tag, isNotEmpty);
      }
    });
  });
}
