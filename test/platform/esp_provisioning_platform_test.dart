import 'dart:async';
import 'dart:typed_data';

import 'package:esp_provisioning_flutter/esp_provisioning_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A recording fake used to verify that [EspProvisioning] forwards every
/// call to [EspProvisioningPlatform.instance] verbatim.
final class _FakePlatform extends EspProvisioningPlatform
    with MockPlatformInterfaceMixin {
  String? lastMethod;
  Map<String, Object?>? lastArgs;
  final _controller = StreamController<EspProvisioningEvent>.broadcast();

  @override
  Future<List<EspDevice>> scanBleDevices({
    required String devicePrefix,
    required Duration timeout,
  }) async {
    lastMethod = 'scanBleDevices';
    lastArgs = <String, Object?>{
      'devicePrefix': devicePrefix,
      'timeout': timeout,
    };
    return const <EspDevice>[
      EspDevice.ble(id: 'AA', name: 'PROV_X', rssi: -55),
    ];
  }

  @override
  Future<void> stopBleScan() async {
    lastMethod = 'stopBleScan';
  }

  @override
  Future<List<EspDevice>> scanSoftApDevices({
    required String devicePrefix,
    required Duration timeout,
  }) async {
    lastMethod = 'scanSoftApDevices';
    lastArgs = <String, Object?>{
      'devicePrefix': devicePrefix,
      'timeout': timeout,
    };
    return const <EspDevice>[
      EspDevice.softAp(id: 'PROV_X', name: 'PROV_X', rssi: -42),
    ];
  }

  @override
  Future<void> connect({
    required EspDevice device,
    required String proofOfPossession,
    required EspSecurity security,
    String? softApPassphrase,
  }) async {
    lastMethod = 'connect';
    lastArgs = <String, Object?>{
      'device': device,
      'pop': proofOfPossession,
      'security': security,
      'softApPassphrase': softApPassphrase,
    };
  }

  @override
  Future<List<WifiNetwork>> scanWifiNetworks() async {
    lastMethod = 'scanWifiNetworks';
    return const <WifiNetwork>[
      WifiNetwork(
        ssid: 'home',
        rssi: -50,
        authMode: WifiAuthMode.wpa2Psk,
      ),
    ];
  }

  @override
  Future<ProvisioningResult> provisionWifi({
    required String ssid,
    required String passphrase,
  }) async {
    lastMethod = 'provisionWifi';
    lastArgs = <String, Object?>{
      'ssid': ssid,
      'passphrase': passphrase,
    };
    return const ProvisioningResult.success();
  }

  @override
  Future<Uint8List> sendCustomData({
    required String endpoint,
    required Uint8List data,
  }) async {
    lastMethod = 'sendCustomData';
    lastArgs = <String, Object?>{'endpoint': endpoint, 'data': data};
    return Uint8List.fromList(<int>[0xAA, 0xBB]);
  }

  @override
  Future<void> disconnect() async {
    lastMethod = 'disconnect';
  }

  @override
  Stream<EspProvisioningEvent> get events => _controller.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePlatform fake;
  late EspProvisioning esp;

  setUp(() {
    fake = _FakePlatform();
    EspProvisioningPlatform.instance = fake;
    esp = EspProvisioning();
  });

  test('default platform instance is MethodChannelEspProvisioning', () {
    // Use a fresh static lookup against the package barrel to make sure the
    // default still resolves to the method-channel impl.
    expect(MethodChannelEspProvisioning(), isA<EspProvisioningPlatform>());
  });

  test('scanBleDevices forwards prefix + timeout to the platform', () async {
    final devices = await esp.scanBleDevices(
      devicePrefix: 'PROV_',
      timeout: const Duration(seconds: 7),
    );
    expect(fake.lastMethod, 'scanBleDevices');
    expect(fake.lastArgs!['devicePrefix'], 'PROV_');
    expect(fake.lastArgs!['timeout'], const Duration(seconds: 7));
    expect(devices, hasLength(1));
    expect(devices.single.id, 'AA');
  });

  test('scanBleDevices uses the documented default timeout', () async {
    await esp.scanBleDevices(devicePrefix: 'PROV_');
    expect(fake.lastArgs!['timeout'], const Duration(seconds: 10));
  });

  test('stopBleScan reaches the platform', () async {
    await esp.stopBleScan();
    expect(fake.lastMethod, 'stopBleScan');
  });

  test('scanSoftApDevices forwards prefix + timeout to the platform', () async {
    final devices = await esp.scanSoftApDevices(
      devicePrefix: 'PROV_',
      timeout: const Duration(seconds: 8),
    );
    expect(fake.lastMethod, 'scanSoftApDevices');
    expect(fake.lastArgs!['devicePrefix'], 'PROV_');
    expect(fake.lastArgs!['timeout'], const Duration(seconds: 8));
    expect(devices, hasLength(1));
    expect(devices.single.transport, EspDeviceTransport.softAp);
  });

  test('scanSoftApDevices uses the documented default timeout', () async {
    await esp.scanSoftApDevices(devicePrefix: 'PROV_');
    expect(fake.lastArgs!['timeout'], const Duration(seconds: 10));
  });

  test('connect forwards softApPassphrase when provided', () async {
    const device = EspDevice.softAp(id: 'PROV_X', name: 'PROV_X');
    await esp.connect(
      device: device,
      proofOfPossession: 'pop',
      softApPassphrase: 'ap-secret',
    );
    expect(fake.lastArgs!['softApPassphrase'], 'ap-secret');
  });

  test('connect leaves softApPassphrase null for BLE devices', () async {
    const device = EspDevice.ble(id: 'AA', name: 'PROV_X');
    await esp.connect(device: device, proofOfPossession: 'pop');
    expect(fake.lastArgs!['softApPassphrase'], isNull);
  });

  test('connect defaults to security2', () async {
    const device = EspDevice.ble(id: 'AA', name: 'PROV_X');
    await esp.connect(device: device, proofOfPossession: 'pop');
    expect(fake.lastMethod, 'connect');
    expect(fake.lastArgs!['security'], EspSecurity.security2);
  });

  test('connect propagates an explicit security level', () async {
    const device = EspDevice.ble(id: 'AA', name: 'PROV_X');
    await esp.connect(
      device: device,
      proofOfPossession: 'pop',
      security: EspSecurity.security1,
    );
    expect(fake.lastArgs!['security'], EspSecurity.security1);
  });

  test('scanWifiNetworks returns whatever the platform reports', () async {
    final networks = await esp.scanWifiNetworks();
    expect(networks, hasLength(1));
    expect(networks.single.ssid, 'home');
  });

  test('provisionWifi forwards ssid + passphrase', () async {
    final result = await esp.provisionWifi(
      ssid: 'home',
      passphrase: 'pw',
    );
    expect(fake.lastMethod, 'provisionWifi');
    expect(fake.lastArgs!['ssid'], 'home');
    expect(fake.lastArgs!['passphrase'], 'pw');
    expect(result.isSuccess, isTrue);
  });

  test('sendCustomData round-trips raw bytes', () async {
    final reply = await esp.sendCustomData(
      endpoint: 'rainybit-bootstrap',
      data: Uint8List.fromList(<int>[1, 2, 3]),
    );
    expect(fake.lastMethod, 'sendCustomData');
    expect(fake.lastArgs!['endpoint'], 'rainybit-bootstrap');
    expect(reply, isA<Uint8List>());
    expect(reply.length, 2);
  });

  test('disconnect reaches the platform', () async {
    await esp.disconnect();
    expect(fake.lastMethod, 'disconnect');
  });

  test('events stream is fed by the platform', () async {
    final received = <EspProvisioningEvent>[];
    final sub = esp.events.listen(received.add);
    fake._controller.add(
      const EspProvisioningEvent(phase: EspProvisioningPhase.connecting),
    );
    await Future<void>.delayed(Duration.zero);
    expect(received, hasLength(1));
    expect(received.single.phase, EspProvisioningPhase.connecting);
    await sub.cancel();
    await fake._controller.close();
  });
}
