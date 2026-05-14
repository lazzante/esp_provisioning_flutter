import 'package:esp_provisioning_flutter/esp_provisioning_flutter.dart';
import 'package:esp_provisioning_flutter_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('example app renders provisioning home page',
      (WidgetTester tester) async {
    await tester.pumpWidget(const EspProvisioningExampleApp());

    expect(find.text('esp_provisioning_flutter'), findsOneWidget);
    // Only assert items that fit the viewport in a default test surface;
    // the ListView lazily builds offscreen items, so anything below the
    // fold won't appear in the widget tree until scrolled into view.
    expect(find.text('1. Scan ble devices'), findsOneWidget);
    expect(find.byType(SegmentedButton<EspDeviceTransport>), findsOneWidget);
  });
}
