import 'package:esp_provisioning_flutter/esp_provisioning_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProvisioningResult', () {
    test('success constructor sets status correctly', () {
      const r = ProvisioningResult.success();
      expect(r.status, ProvisioningStatus.success);
      expect(r.isSuccess, isTrue);
      expect(r.rawCode, isNull);
      expect(r.rawMessage, isNull);
    });

    test('failure constructor preserves raw fields', () {
      const r = ProvisioningResult.failure(
        status: ProvisioningStatus.authFailed,
        rawCode: 401,
        rawMessage: 'bad password',
      );
      expect(r.isSuccess, isFalse);
      expect(r.rawCode, 401);
      expect(r.rawMessage, 'bad password');
    });

    test('round-trips through map for every status', () {
      for (final status in ProvisioningStatus.values) {
        final original = ProvisioningResult(
          status: status,
          rawCode: 7,
          rawMessage: 'm',
        );
        final decoded = ProvisioningResult.fromMap(original.toMap());
        expect(
          decoded.status,
          status,
          reason: 'round-trip failed for $status',
        );
      }
    });

    test('fromMap maps unknown status string to .unknown', () {
      final r = ProvisioningResult.fromMap(<Object?, Object?>{
        'status': 'not-a-real-status',
      });
      expect(r.status, ProvisioningStatus.unknown);
    });

    test('fromMap throws on missing status field', () {
      expect(
        () => ProvisioningResult.fromMap(const <Object?, Object?>{}),
        throwsFormatException,
      );
    });

    test('fromMap throws on wrong-typed rawCode', () {
      expect(
        () => ProvisioningResult.fromMap(<Object?, Object?>{
          'status': 'success',
          'rawCode': 'not-int',
        }),
        throwsFormatException,
      );
    });

    test('equality / hashCode by all three fields', () {
      const a = ProvisioningResult(
        status: ProvisioningStatus.authFailed,
        rawCode: 1,
        rawMessage: 'a',
      );
      const b = ProvisioningResult(
        status: ProvisioningStatus.authFailed,
        rawCode: 1,
        rawMessage: 'a',
      );
      const c = ProvisioningResult(
        status: ProvisioningStatus.authFailed,
        rawCode: 2,
        rawMessage: 'a',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });
}
