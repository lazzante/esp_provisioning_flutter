part of 'esp_provisioning_exception.dart';

/// Thrown when BLE provisioning is requested but the host device cannot
/// perform BLE — Bluetooth is off, the radio is missing, or the system is
/// currently in airplane mode.
///
/// On Android this typically corresponds to `BluetoothAdapter` being `null`
/// or disabled; on iOS to `CBCentralManager.state` being `.poweredOff`,
/// `.unsupported`, or `.resetting`.
///
/// Distinct from [PermissionDeniedException], which means BLE is available
/// but the OS refused the app access to it.
final class BleUnavailableException extends EspProvisioningException {
  /// Creates the exception. The string code is fixed to `ble_unavailable`.
  const BleUnavailableException({
    required super.message,
    super.cause,
  }) : super(code: 'ble_unavailable');
}
