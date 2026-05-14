package com.rainybit.esp_provisioning_flutter

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat

/**
 * Coarse Bluetooth availability classification used by the bridge to choose
 * the right typed FlutterError before launching a scan. Mirrors the
 * iOS-side [BluetoothStateProbe] semantics: `available` means proceed,
 * `poweredOff` maps to `ble_unavailable`, and `permissionDenied` maps to
 * `permission_denied` with `permission` in the FlutterError details.
 */
internal sealed class BluetoothAvailability {
    object Available : BluetoothAvailability()
    object PoweredOff : BluetoothAvailability()
    data class PermissionDenied(val permission: String) : BluetoothAvailability()
}

/**
 * Resolves BLE readiness ahead of every scan. Cheap and synchronous —
 * Android's [BluetoothAdapter] exposes power state without callbacks, so
 * we do not need the async settle-time dance the iOS probe goes through.
 *
 * Permission checks consult [ContextCompat.checkSelfPermission] against the
 * current app context. The plugin intentionally does *not* prompt the
 * user; the host app owns prompt timing.
 */
internal object BluetoothStateProbe {

    fun check(context: Context): BluetoothAvailability {
        val adapter = bluetoothAdapter(context)
        if (adapter == null || !adapter.isEnabled) {
            return BluetoothAvailability.PoweredOff
        }
        return checkRuntimePermissions(context)
    }

    private fun bluetoothAdapter(context: Context): BluetoothAdapter? {
        val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            ?: return null
        return manager.adapter
    }

    private fun checkRuntimePermissions(context: Context): BluetoothAvailability {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S /* 31 */) {
            val scanGranted = ContextCompat.checkSelfPermission(
                context, Manifest.permission.BLUETOOTH_SCAN
            ) == PackageManager.PERMISSION_GRANTED
            if (!scanGranted) {
                return BluetoothAvailability.PermissionDenied("bluetooth_scan")
            }
            val connectGranted = ContextCompat.checkSelfPermission(
                context, Manifest.permission.BLUETOOTH_CONNECT
            ) == PackageManager.PERMISSION_GRANTED
            if (!connectGranted) {
                return BluetoothAvailability.PermissionDenied("bluetooth_connect")
            }
        } else {
            // Android 11 and below: BLE scans count as a location-sensitive
            // operation, so the platform requires ACCESS_FINE_LOCATION.
            val locationGranted = ContextCompat.checkSelfPermission(
                context, Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
            if (!locationGranted) {
                return BluetoothAvailability.PermissionDenied("location")
            }
        }
        return BluetoothAvailability.Available
    }
}
