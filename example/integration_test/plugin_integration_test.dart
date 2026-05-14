// Placeholder integration test — exercises the example app boots without
// touching real hardware. Real on-device integration tests against an ESP32
// land in PR #6 once native bridges are wired.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:esp_provisioning_flutter/esp_provisioning_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plugin instance can be constructed', (WidgetTester tester) async {
    final esp = EspProvisioning();
    expect(esp, isNotNull);
  });
}
