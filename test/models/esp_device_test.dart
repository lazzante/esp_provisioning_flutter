import 'package:esp_provisioning_flutter/esp_provisioning_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EspDevice', () {
    test('ble named constructor sets transport correctly', () {
      const d = EspDevice.ble(
        id: 'AA:BB:CC',
        name: 'PROV_X',
        rssi: -55,
        serviceUuid: '021a9004-0382-4aea-bff4-6b3f1c5adfb4',
      );
      expect(d.transport, EspDeviceTransport.ble);
      expect(d.rssi, -55);
      expect(d.serviceUuid, isNotNull);
      expect(d.bssid, isNull);
    });

    test('softAp named constructor sets transport correctly', () {
      const d = EspDevice.softAp(
        id: 'PROV_X',
        name: 'PROV_X',
        bssid: 'ab:cd:ef:01:02:03',
      );
      expect(d.transport, EspDeviceTransport.softAp);
      expect(d.bssid, isNotNull);
      expect(d.serviceUuid, isNull);
    });

    test('toMap / fromMap round-trips losslessly (BLE)', () {
      const original = EspDevice.ble(
        id: 'AA:BB:CC',
        name: 'PROV_X',
        rssi: -55,
        serviceUuid: '021a9004-0382-4aea-bff4-6b3f1c5adfb4',
      );
      final decoded = EspDevice.fromMap(original.toMap());
      expect(decoded, original);
      expect(decoded.rssi, original.rssi);
      expect(decoded.serviceUuid, original.serviceUuid);
    });

    test('toMap / fromMap round-trips losslessly (SoftAP)', () {
      const original = EspDevice.softAp(
        id: 'PROV_X',
        name: 'PROV_X',
        bssid: 'ab:cd:ef:01:02:03',
      );
      final decoded = EspDevice.fromMap(original.toMap());
      expect(decoded, original);
      expect(decoded.bssid, original.bssid);
    });

    test('accepts legacy "softap" transport spelling', () {
      final d = EspDevice.fromMap(<Object?, Object?>{
        'id': 'PROV_X',
        'name': 'PROV_X',
        'transport': 'softap',
      });
      expect(d.transport, EspDeviceTransport.softAp);
    });

    test('fromMap throws on missing id', () {
      expect(
        () => EspDevice.fromMap(<Object?, Object?>{
          'name': 'PROV_X',
          'transport': 'ble',
        }),
        throwsFormatException,
      );
    });

    test('fromMap throws on missing name', () {
      expect(
        () => EspDevice.fromMap(<Object?, Object?>{
          'id': 'AA',
          'transport': 'ble',
        }),
        throwsFormatException,
      );
    });

    test('fromMap throws on unknown transport', () {
      expect(
        () => EspDevice.fromMap(<Object?, Object?>{
          'id': 'AA',
          'name': 'PROV_X',
          'transport': 'zigbee',
        }),
        throwsFormatException,
      );
    });

    test('fromMap throws on wrong-type rssi', () {
      expect(
        () => EspDevice.fromMap(<Object?, Object?>{
          'id': 'AA',
          'name': 'PROV_X',
          'transport': 'ble',
          'rssi': 'not-an-int',
        }),
        throwsFormatException,
      );
    });

    test('equality is by id + transport, not optional fields', () {
      const a = EspDevice.ble(id: 'AA', name: 'PROV_X', rssi: -50);
      const b = EspDevice.ble(id: 'AA', name: 'PROV_Y', rssi: -70);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different transports are not equal', () {
      const a = EspDevice.ble(id: 'AA', name: 'PROV_X');
      const b = EspDevice.softAp(id: 'AA', name: 'PROV_X');
      expect(a, isNot(equals(b)));
    });

    test('copyWith overrides only specified fields', () {
      const original = EspDevice.ble(id: 'AA', name: 'PROV_X', rssi: -50);
      final updated = original.copyWith(name: 'PROV_Y');
      expect(updated.id, 'AA');
      expect(updated.name, 'PROV_Y');
      expect(updated.rssi, -50);
    });

    test('toString does not throw for any combination', () {
      const a = EspDevice.ble(id: 'AA', name: 'PROV_X');
      const b = EspDevice.softAp(id: 'AA', name: 'PROV_X', rssi: -60);
      expect(a.toString(), contains('EspDevice'));
      expect(b.toString(), contains('softAp'));
    });
  });
}
