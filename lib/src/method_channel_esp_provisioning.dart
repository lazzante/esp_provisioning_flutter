import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'esp_provisioning_platform.dart';
import 'exceptions/esp_provisioning_exception.dart';
import 'exceptions/exception_mapper.dart';
import 'models/esp_device.dart';
import 'models/esp_provisioning_event.dart';
import 'models/esp_security.dart';
import 'models/provisioning_result.dart';
import 'models/wifi_network.dart';

/// The default federated implementation, backed by a [MethodChannel] for
/// imperative calls and an [EventChannel] for the lifecycle event stream.
///
/// Visible-for-testing fields allow Dart unit tests to substitute their own
/// channel handlers; production code should use the [EspProvisioning]
/// facade and never reach in here directly.
final class MethodChannelEspProvisioning extends EspProvisioningPlatform {
  /// Creates the default implementation with the conventional channel names.
  /// Tests may substitute alternative channels — see [methodChannel] and
  /// [eventChannel] visible-for-testing fields.
  MethodChannelEspProvisioning();

  /// The method channel used for one-shot RPC-style calls (`scan`,
  /// `connect`, …). Exposed for tests via `@visibleForTesting`.
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel(
    'com.rainybit.esp_provisioning_flutter/methods',
  );

  /// The event channel used for the lifecycle event stream. Exposed for
  /// tests via `@visibleForTesting`.
  @visibleForTesting
  final EventChannel eventChannel = const EventChannel(
    'com.rainybit.esp_provisioning_flutter/events',
  );

  Stream<EspProvisioningEvent>? _eventsStream;

  @override
  Future<List<EspDevice>> scanBleDevices({
    required String devicePrefix,
    required Duration timeout,
  }) async {
    return _invoke<List<EspDevice>>('scanBleDevices', <String, Object?>{
      'devicePrefix': devicePrefix,
      'timeoutMs': timeout.inMilliseconds,
    }, (Object? raw) {
      if (raw is! List) {
        throw const FormatException(
          'scanBleDevices: expected a list of devices',
        );
      }
      return raw
          .whereType<Map>()
          .map((m) => EspDevice.fromMap(Map<Object?, Object?>.from(m)))
          .toList(growable: false);
    });
  }

  @override
  Future<void> stopBleScan() async {
    await _invoke<void>('stopBleScan', null, (_) {});
  }

  @override
  Future<void> connect({
    required EspDevice device,
    required String proofOfPossession,
    required EspSecurity security,
  }) async {
    await _invoke<void>('connect', <String, Object?>{
      'device': device.toMap(),
      'proofOfPossession': proofOfPossession,
      'security': security.protocolVersion,
    }, (_) {});
  }

  @override
  Future<List<WifiNetwork>> scanWifiNetworks() async {
    return _invoke<List<WifiNetwork>>('scanWifiNetworks', null, (Object? raw) {
      if (raw is! List) {
        throw const FormatException(
          'scanWifiNetworks: expected a list of networks',
        );
      }
      return raw
          .whereType<Map>()
          .map((m) => WifiNetwork.fromMap(Map<Object?, Object?>.from(m)))
          .toList(growable: false);
    });
  }

  @override
  Future<ProvisioningResult> provisionWifi({
    required String ssid,
    required String passphrase,
  }) async {
    return _invoke<ProvisioningResult>('provisionWifi', <String, Object?>{
      'ssid': ssid,
      'passphrase': passphrase,
    }, (Object? raw) {
      if (raw is! Map) {
        throw const FormatException(
          'provisionWifi: expected a result map',
        );
      }
      return ProvisioningResult.fromMap(Map<Object?, Object?>.from(raw));
    });
  }

  @override
  Future<Uint8List> sendCustomData({
    required String endpoint,
    required Uint8List data,
  }) async {
    return _invoke<Uint8List>('sendCustomData', <String, Object?>{
      'endpoint': endpoint,
      'data': data,
    }, (Object? raw) {
      if (raw is Uint8List) return raw;
      if (raw is List<int>) return Uint8List.fromList(raw);
      throw const FormatException(
        'sendCustomData: expected Uint8List response',
      );
    });
  }

  @override
  Future<void> disconnect() async {
    await _invoke<void>('disconnect', null, (_) {});
  }

  @override
  Stream<EspProvisioningEvent> get events {
    return _eventsStream ??= eventChannel
        .receiveBroadcastStream()
        .map<EspProvisioningEvent>((Object? raw) {
          if (raw is! Map) {
            throw const FormatException(
              'events stream: expected a map payload',
            );
          }
          return EspProvisioningEvent.fromMap(
            Map<Object?, Object?>.from(raw),
          );
        });
  }

  Future<T> _invoke<T>(
    String method,
    Map<String, Object?>? arguments,
    T Function(Object? raw) decode,
  ) async {
    try {
      final raw = await methodChannel.invokeMethod<Object?>(method, arguments);
      return decode(raw);
    } on PlatformException catch (error) {
      throw mapPlatformException(error);
    } on MissingPluginException catch (error) {
      throw SessionFailedException(
        message: 'Native plugin did not implement method "$method"',
        code: 'method_not_implemented',
        cause: error,
      );
    }
  }
}
