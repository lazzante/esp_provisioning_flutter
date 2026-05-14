import 'package:esp_provisioning_flutter/esp_provisioning_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EspProvisioningEvent', () {
    test('decodes a minimal event with only a phase', () {
      final e = EspProvisioningEvent.fromMap(<Object?, Object?>{
        'phase': 'connecting',
      });
      expect(e.phase, EspProvisioningPhase.connecting);
      expect(e.deviceId, isNull);
      expect(e.message, isNull);
      expect(e.result, isNull);
    });

    test('decodes a finished event with embedded result', () {
      final e = EspProvisioningEvent.fromMap(<Object?, Object?>{
        'phase': 'finished',
        'deviceId': 'PROV_X',
        'result': <Object?, Object?>{
          'status': 'success',
        },
      });
      expect(e.phase, EspProvisioningPhase.finished);
      expect(e.deviceId, 'PROV_X');
      expect(e.result, isNotNull);
      expect(e.result!.isSuccess, isTrue);
    });

    test('throws on missing phase', () {
      expect(
        () =>
            EspProvisioningEvent.fromMap(const <Object?, Object?>{}),
        throwsFormatException,
      );
    });

    test('throws on unknown phase string', () {
      expect(
        () => EspProvisioningEvent.fromMap(<Object?, Object?>{
          'phase': 'teleporting',
        }),
        throwsFormatException,
      );
    });

    test('throws when result field is not a map', () {
      expect(
        () => EspProvisioningEvent.fromMap(<Object?, Object?>{
          'phase': 'finished',
          'result': 'not-a-map',
        }),
        throwsFormatException,
      );
    });

    test('throws on non-string deviceId', () {
      expect(
        () => EspProvisioningEvent.fromMap(<Object?, Object?>{
          'phase': 'connecting',
          'deviceId': 42,
        }),
        throwsFormatException,
      );
    });

    test('every defined phase parses', () {
      const phases = <String, EspProvisioningPhase>{
        'scanStarted': EspProvisioningPhase.scanStarted,
        'scanFinished': EspProvisioningPhase.scanFinished,
        'connecting': EspProvisioningPhase.connecting,
        'sessionEstablishing': EspProvisioningPhase.sessionEstablishing,
        'sessionEstablished': EspProvisioningPhase.sessionEstablished,
        'wifiScanning': EspProvisioningPhase.wifiScanning,
        'applyingCredentials': EspProvisioningPhase.applyingCredentials,
        'finished': EspProvisioningPhase.finished,
        'disconnected': EspProvisioningPhase.disconnected,
      };
      for (final entry in phases.entries) {
        final event = EspProvisioningEvent.fromMap(<Object?, Object?>{
          'phase': entry.key,
        });
        expect(event.phase, entry.value, reason: entry.key);
      }
    });
  });
}
