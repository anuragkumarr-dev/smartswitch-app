import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service contract for requesting and checking permissions required for smart switch onboarding.
/// Android: API 31+ (Bluetooth Scan, Bluetooth Connect) vs legacy Android (Location, Bluetooth),
/// iOS: Camera and Bluetooth,
/// plus Camera for QR code scanning across all platforms.
abstract interface class PermissionService {
  /// Checks and requests camera access for QR scanning.
  Future<bool> checkAndRequestCameraPermission();

  /// Checks and requests Bluetooth (and location if required on older Android) permissions.
  Future<bool> checkAndRequestBluetoothPermissions();

  /// Checks and requests all permissions required for onboarding.
  Future<bool> checkAndRequestAllOnboardingPermissions();
}

/// Production implementation of [PermissionService] using `permission_handler`.
class AppPermissionService implements PermissionService {
  const AppPermissionService();

  @override
  Future<bool> checkAndRequestCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted || status.isLimited) {
      return true;
    }
    final result = await Permission.camera.request();
    return result.isGranted || result.isLimited;
  }

  @override
  Future<bool> checkAndRequestBluetoothPermissions() async {
    if (kIsWeb) return true;

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android 12+ (API 31+) uses BLUETOOTH_SCAN and BLUETOOTH_CONNECT.
      // Older Android requires Location permission to discover BLE beacons.
      final permissions = <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ];

      final statuses = await permissions.request();

      // For Android 12+, bluetoothScan is required. For older Android, location is required.
      final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
      final connectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
      final locationGranted = statuses[Permission.locationWhenInUse]?.isGranted ?? false;

      // Succeeded if either API 31+ permissions granted OR legacy location granted
      return (scanGranted && connectGranted) || locationGranted;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final status = await Permission.bluetooth.request();
      return status.isGranted || status.isLimited;
    }

    return true;
  }

  @override
  Future<bool> checkAndRequestAllOnboardingPermissions() async {
    final cameraOk = await checkAndRequestCameraPermission();
    if (!cameraOk) return false;

    final bleOk = await checkAndRequestBluetoothPermissions();
    return bleOk;
  }
}

/// Fake permission service for unit testing and debug environments.
class FakePermissionService implements PermissionService {
  bool cameraGranted;
  bool bluetoothGranted;

  FakePermissionService({
    this.cameraGranted = true,
    this.bluetoothGranted = true,
  });

  @override
  Future<bool> checkAndRequestCameraPermission() async => cameraGranted;

  @override
  Future<bool> checkAndRequestBluetoothPermissions() async => bluetoothGranted;

  @override
  Future<bool> checkAndRequestAllOnboardingPermissions() async {
    return cameraGranted && bluetoothGranted;
  }
}
