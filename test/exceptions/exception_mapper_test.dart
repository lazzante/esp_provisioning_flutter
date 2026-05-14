import 'package:esp_provisioning_flutter/esp_provisioning_flutter.dart';
import 'package:esp_provisioning_flutter/src/exceptions/exception_mapper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapPlatformException', () {
    test('ble_unavailable maps to BleUnavailableException', () {
      final mapped = mapPlatformException(
        PlatformException(
          code: 'ble_unavailable',
          message: 'radio off',
        ),
      );
      expect(mapped, isA<BleUnavailableException>());
      expect(mapped.code, 'ble_unavailable');
      expect(mapped.message, 'radio off');
    });

    test('permission_denied extracts the permission detail', () {
      final mapped = mapPlatformException(
        PlatformException(
          code: 'permission_denied',
          message: 'denied',
          details: <String, Object?>{'permission': 'bluetooth_scan'},
        ),
      ) as PermissionDeniedException;
      expect(mapped.permission, 'bluetooth_scan');
    });

    test('permission_denied tolerates missing details map', () {
      final mapped = mapPlatformException(
        PlatformException(
          code: 'permission_denied',
          message: 'denied',
        ),
      ) as PermissionDeniedException;
      expect(mapped.permission, 'unknown');
    });

    test('device_not_found extracts the deviceId detail', () {
      final mapped = mapPlatformException(
        PlatformException(
          code: 'device_not_found',
          message: 'gone',
          details: <String, Object?>{'deviceId': 'PROV_X'},
        ),
      ) as DeviceNotFoundException;
      expect(mapped.deviceId, 'PROV_X');
    });

    test('pop_invalid maps to PopInvalidException', () {
      final mapped = mapPlatformException(
        PlatformException(code: 'pop_invalid', message: 'bad pop'),
      );
      expect(mapped, isA<PopInvalidException>());
    });

    test('session_failed maps to SessionFailedException', () {
      final mapped = mapPlatformException(
        PlatformException(code: 'session_failed', message: 'oops'),
      );
      expect(mapped, isA<SessionFailedException>());
    });

    test('wifi_provisioning_failed maps to WifiProvisioningFailedException', () {
      final mapped = mapPlatformException(
        PlatformException(
          code: 'wifi_provisioning_failed',
          message: 'apply failed',
        ),
      );
      expect(mapped, isA<WifiProvisioningFailedException>());
    });

    test('softap_connection_failed extracts ssid', () {
      final mapped = mapPlatformException(
        PlatformException(
          code: 'softap_connection_failed',
          message: 'nope',
          details: <String, Object?>{'ssid': 'PROV_X'},
        ),
      ) as SoftApConnectionException;
      expect(mapped.ssid, 'PROV_X');
    });

    test('unknown native codes fall through to SessionFailedException', () {
      final mapped = mapPlatformException(
        PlatformException(
          code: 'something_brand_new',
          message: 'who knows',
        ),
      );
      expect(mapped, isA<SessionFailedException>());
      expect(mapped.message, contains('something_brand_new'));
    });

    test('preserves the cause for telemetry', () {
      final original = PlatformException(
        code: 'session_failed',
        message: 'm',
      );
      final mapped = mapPlatformException(original);
      expect(mapped.cause, same(original));
    });

    test('toString includes code + message', () {
      final mapped = mapPlatformException(
        PlatformException(code: 'pop_invalid', message: 'bad pop'),
      );
      final s = mapped.toString();
      expect(s, contains('pop_invalid'));
      expect(s, contains('bad pop'));
    });
  });

  group('Exception hierarchy', () {
    test('every concrete exception extends the sealed base', () {
      const cases = <EspProvisioningException>[
        BleUnavailableException(message: ''),
        PermissionDeniedException(message: '', permission: 'p'),
        DeviceNotFoundException(message: '', deviceId: 'd'),
        PopInvalidException(message: ''),
        SessionFailedException(message: ''),
        WifiProvisioningFailedException(message: ''),
        SoftApConnectionException(message: '', ssid: 's'),
      ];
      for (final c in cases) {
        expect(c, isA<EspProvisioningException>());
      }
    });

    test('sealed switch over exceptions is exhaustive', () {
      const cases = <EspProvisioningException>[
        BleUnavailableException(message: ''),
        PermissionDeniedException(message: '', permission: 'p'),
        DeviceNotFoundException(message: '', deviceId: 'd'),
        PopInvalidException(message: ''),
        SessionFailedException(message: ''),
        WifiProvisioningFailedException(message: ''),
        SoftApConnectionException(message: '', ssid: 's'),
      ];
      for (final c in cases) {
        final tag = switch (c) {
          BleUnavailableException() => 'ble',
          PermissionDeniedException() => 'perm',
          DeviceNotFoundException() => 'notfound',
          PopInvalidException() => 'pop',
          SessionFailedException() => 'session',
          WifiProvisioningFailedException() => 'wifi',
          SoftApConnectionException() => 'softap',
        };
        expect(tag, isNotEmpty);
      }
    });
  });
}
