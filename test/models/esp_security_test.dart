import 'package:esp_provisioning_flutter/esp_provisioning_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EspSecurity', () {
    test('protocolVersion maps each variant to its ESP-IDF integer', () {
      expect(EspSecurity.security0.protocolVersion, 0);
      expect(EspSecurity.security1.protocolVersion, 1);
      expect(EspSecurity.security2.protocolVersion, 2);
    });

    test('fromProtocolVersion round-trips every variant', () {
      for (final s in EspSecurity.values) {
        expect(EspSecurity.fromProtocolVersion(s.protocolVersion), s);
      }
    });

    test('fromProtocolVersion throws on unknown value', () {
      expect(() => EspSecurity.fromProtocolVersion(99), throwsArgumentError);
      expect(() => EspSecurity.fromProtocolVersion(-1), throwsArgumentError);
    });
  });
}
