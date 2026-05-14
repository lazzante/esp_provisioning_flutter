import 'package:esp_provisioning_flutter_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('example app renders provisioning home page',
      (WidgetTester tester) async {
    await tester.pumpWidget(const EspProvisioningExampleApp());

    expect(find.text('esp_provisioning_flutter'), findsOneWidget);
    expect(find.text('1. Scan BLE devices'), findsOneWidget);
    expect(find.text('2. Scan Wi-Fi'), findsOneWidget);
    expect(find.text('3. Provision Wi-Fi'), findsOneWidget);
  });
}
