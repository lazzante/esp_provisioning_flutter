/// Flutter plugin for provisioning ESP32 devices over BLE and SoftAP.
///
/// Wraps Espressif's official iOS ([ESPProvision](https://github.com/espressif/esp-idf-provisioning-ios))
/// and Android ([esp-idf-provisioning-android](https://github.com/espressif/esp-idf-provisioning-android))
/// SDKs and exposes them through a single, sealed Dart API surface.
///
/// The package entry point is [EspProvisioning]; see its documentation for a
/// full usage example.
library;

export 'src/esp_provisioning.dart';
export 'src/esp_provisioning_platform.dart';
export 'src/method_channel_esp_provisioning.dart';

export 'src/models/esp_device.dart';
export 'src/models/esp_provisioning_event.dart';
export 'src/models/esp_security.dart';
export 'src/models/provisioning_result.dart';
export 'src/models/wifi_network.dart';

export 'src/transport/esp_transport.dart';

export 'src/exceptions/esp_provisioning_exception.dart';
