// BluetoothStateProbe.swift
//
// Lightweight Core Bluetooth helper that resolves the platform's BLE
// readiness without performing a scan. Used by `ProvisioningBridge` to
// short-circuit `scanBleDevices` with a typed `BleUnavailableException` /
// `PermissionDeniedException` *before* the SDK fires its generic
// "no device found" path, which would otherwise mask the real cause.
//
// We deliberately retain a single `CBCentralManager` for the probe's
// lifetime — Core Bluetooth requires a stable owner to deliver the
// initial `centralManagerDidUpdateState:` callback, and recreating the
// manager per probe triggers iOS's "unauthorized" sentinel even for apps
// that were granted permission.

import CoreBluetooth
import Foundation

/// Coarse availability classification used by the bridge to choose the
/// right typed exception. Anything `.available` means the scan may
/// proceed; the two failure cases map directly onto the
/// `ble_unavailable` and `permission_denied` codes on the Dart side.
enum BluetoothAvailability {
    case available
    case poweredOff
    case unauthorized
}

final class BluetoothStateProbe: NSObject, CBCentralManagerDelegate {

    private var manager: CBCentralManager?
    private var pendingCompletions: [(BluetoothAvailability) -> Void] = []
    private var resolved = false

    /// Returns the current BLE availability asynchronously. The very first
    /// invocation has to wait for `centralManagerDidUpdateState:` to fire
    /// (typically <50ms); subsequent invocations resolve immediately with
    /// the cached state, refreshed on every system callback.
    func checkAvailability(_ completion: @escaping (BluetoothAvailability) -> Void) {
        if resolved, let manager = manager {
            completion(classify(manager: manager))
            return
        }
        pendingCompletions.append(completion)
        if manager == nil {
            manager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        resolved = true
        let availability = classify(manager: central)
        let pending = pendingCompletions
        pendingCompletions.removeAll()
        for completion in pending {
            completion(availability)
        }
    }

    private func classify(manager: CBCentralManager) -> BluetoothAvailability {
        switch manager.state {
        case .poweredOn:
            return .available
        case .unauthorized:
            return .unauthorized
        case .poweredOff, .unsupported, .resetting, .unknown:
            return .poweredOff
        @unknown default:
            return .poweredOff
        }
    }
}
