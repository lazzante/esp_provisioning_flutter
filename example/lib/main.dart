import 'dart:async';

import 'package:esp_provisioning_flutter/esp_provisioning_flutter.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const EspProvisioningExampleApp());
}

class EspProvisioningExampleApp extends StatelessWidget {
  const EspProvisioningExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'esp_provisioning_flutter example',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const ProvisioningHomePage(),
    );
  }
}

class ProvisioningHomePage extends StatefulWidget {
  const ProvisioningHomePage({super.key});

  @override
  State<ProvisioningHomePage> createState() => _ProvisioningHomePageState();
}

class _ProvisioningHomePageState extends State<ProvisioningHomePage> {
  final EspProvisioning _esp = EspProvisioning();
  final TextEditingController _popController =
      TextEditingController(text: 'abcd1234');
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  List<EspDevice> _devices = const <EspDevice>[];
  EspDevice? _connectedDevice;
  List<WifiNetwork> _networks = const <WifiNetwork>[];
  ProvisioningResult? _lastResult;
  String _status = 'Idle.';
  bool _busy = false;
  StreamSubscription<EspProvisioningEvent>? _eventsSub;

  @override
  void initState() {
    super.initState();
    _eventsSub = _esp.events.listen((event) {
      setState(() {
        _status = 'event: ${event.phase.name}'
            '${event.message == null ? '' : ' — ${event.message}'}';
      });
    });
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _popController.dispose();
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _run(String label, Future<void> Function() body) async {
    setState(() {
      _busy = true;
      _status = '$label …';
    });
    try {
      await body();
      setState(() => _status = '$label ✓');
    } on EspProvisioningException catch (e) {
      setState(() => _status = '$label ✗ ${e.code}: ${e.message}');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _scan() => _run('Scan BLE', () async {
        final devices = await _esp.scanBleDevices(devicePrefix: 'PROV_');
        setState(() => _devices = devices);
      });

  Future<void> _connect(EspDevice device) => _run('Connect', () async {
        await _esp.connect(
          device: device,
          proofOfPossession: _popController.text,
        );
        setState(() => _connectedDevice = device);
      });

  Future<void> _scanWifi() => _run('Scan Wi-Fi', () async {
        final networks = await _esp.scanWifiNetworks();
        setState(() => _networks = networks);
      });

  Future<void> _provision() => _run('Provision', () async {
        final result = await _esp.provisionWifi(
          ssid: _ssidController.text,
          passphrase: _passwordController.text,
        );
        setState(() => _lastResult = result);
      });

  Future<void> _disconnect() => _run('Disconnect', () async {
        await _esp.disconnect();
        setState(() {
          _connectedDevice = null;
          _networks = const <WifiNetwork>[];
        });
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('esp_provisioning_flutter')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Status: $_status', style: const TextStyle(fontFamily: 'monospace')),
            const Divider(height: 32),
            TextField(
              controller: _popController,
              decoration: const InputDecoration(
                labelText: 'Proof of Possession (PoP)',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _scan,
              child: const Text('1. Scan BLE devices'),
            ),
            const SizedBox(height: 8),
            if (_devices.isEmpty)
              const Text('(no devices yet)')
            else
              ..._devices.map(
                (d) => Card(
                  child: ListTile(
                    title: Text(d.name),
                    subtitle: Text('${d.id} • rssi ${d.rssi ?? '?'}'),
                    trailing: TextButton(
                      onPressed: _busy ? null : () => _connect(d),
                      child: const Text('Connect'),
                    ),
                  ),
                ),
              ),
            const Divider(height: 32),
            FilledButton(
              onPressed: _busy || _connectedDevice == null ? null : _scanWifi,
              child: const Text('2. Scan Wi-Fi'),
            ),
            const SizedBox(height: 8),
            if (_networks.isEmpty)
              const Text('(connect first, then scan)')
            else
              ..._networks.map(
                (n) => Card(
                  child: ListTile(
                    title: Text(n.ssid.isEmpty ? '(hidden)' : n.ssid),
                    subtitle: Text(
                      'rssi ${n.rssi} • ${n.authMode.name}'
                      '${n.channel == null ? '' : ' • ch ${n.channel}'}',
                    ),
                    onTap: () => setState(() {
                      _ssidController.text = n.ssid;
                    }),
                  ),
                ),
              ),
            const Divider(height: 32),
            TextField(
              controller: _ssidController,
              decoration: const InputDecoration(labelText: 'SSID'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Passphrase'),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed:
                  _busy || _connectedDevice == null ? null : _provision,
              child: const Text('3. Provision Wi-Fi'),
            ),
            if (_lastResult != null) ...[
              const SizedBox(height: 8),
              Text(
                'Result: ${_lastResult!.status.name}'
                '${_lastResult!.rawMessage == null ? '' : ' — ${_lastResult!.rawMessage}'}',
              ),
            ],
            const Divider(height: 32),
            OutlinedButton(
              onPressed:
                  _busy || _connectedDevice == null ? null : _disconnect,
              child: const Text('Disconnect'),
            ),
          ],
        ),
      ),
    );
  }
}
