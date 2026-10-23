import 'package:flutter/foundation.dart';
import '../core/errors/provisioning_error.dart';

/// Represents a nearby BLE device advertising ESP unified provisioning service.
@immutable
class BleDiscoveredDevice {
  /// Hardware identifier (MAC address on Android, UUID on iOS).
  final String id;

  /// Advertised local name, e.g. "PROV_dev_9a41b2" or "SW_dev_9a41b2".
  final String name;

  /// Parsed deviceId from advertisement name or manufacturer data.
  final String? deviceId;

  /// Received signal strength indicator.
  final int rssi;

  /// Advertised service UUIDs.
  final List<String> serviceUuids;

  const BleDiscoveredDevice({
    required this.id,
    required this.name,
    this.deviceId,
    this.rssi = -60,
    this.serviceUuids = const [],
  });

  /// Checks whether this advertisement strictly matches the expected [targetDeviceId].
  /// Matches if [deviceId] equals [targetDeviceId] or if the advertised name
  /// contains or ends with the target device ID.
  bool matchesDeviceId(String targetDeviceId) {
    if (targetDeviceId.isEmpty) return false;
    if (deviceId != null && deviceId == targetDeviceId) {
      return true;
    }
    // ESP-IDF unified provisioning typically advertises "PROV_<deviceId>" or "<prefix>_<deviceId>"
    final cleanName = name.trim();
    if (cleanName == targetDeviceId) return true;
    if (cleanName.endsWith('_$targetDeviceId') || cleanName.endsWith(':$targetDeviceId')) {
      return true;
    }
    if (cleanName.contains(targetDeviceId)) {
      return true;
    }
    return false;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleDiscoveredDevice &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          deviceId == other.deviceId;

  @override
  int get hashCode => Object.hash(id, name, deviceId);

  @override
  String toString() =>
      'BleDiscoveredDevice(id: $id, name: $name, deviceId: $deviceId, rssi: $rssi)';
}

/// Device metadata returned after establishing the secure protocomm session.
@immutable
class ProvisioningDeviceInfo {
  final String productId;
  final String deviceId;
  final String firmwareVersion;
  final bool isProvisioned;
  final List<String> capabilities;

  const ProvisioningDeviceInfo({
    required this.productId,
    required this.deviceId,
    required this.firmwareVersion,
    required this.isProvisioned,
    this.capabilities = const ['wifi_scan', 'no_pop', 'sec2'],
  });

  @override
  String toString() =>
      'ProvisioningDeviceInfo(productId: $productId, deviceId: $deviceId, fw: $firmwareVersion, isProvisioned: $isProvisioned)';
}

/// Statuses streamed by the switch over BLE notifications (Blueprint §2.2 step 9).
enum DeviceProvisioningState {
  wifiConnecting,
  wifiOk,
  meshJoined,
  cloudReached,
  error,
}

/// A status event reported by the ESP switch during provisioning execution.
@immutable
class DeviceProvisioningStatus {
  final DeviceProvisioningState state;
  final String rawStatus;
  final String? message;
  final int? meshLayer;
  final ProvisioningFailureType? failureType;

  const DeviceProvisioningStatus({
    required this.state,
    required this.rawStatus,
    this.message,
    this.meshLayer,
    this.failureType,
  });

  /// Convenience factory for normal progression events
  factory DeviceProvisioningStatus.wifiConnecting() => const DeviceProvisioningStatus(
        state: DeviceProvisioningState.wifiConnecting,
        rawStatus: 'WIFI_CONNECTING',
        message: 'Connecting to Wi-Fi network...',
      );

  factory DeviceProvisioningStatus.wifiOk() => const DeviceProvisioningStatus(
        state: DeviceProvisioningState.wifiOk,
        rawStatus: 'WIFI_OK',
        message: 'Connected to Wi-Fi successfully',
      );

  factory DeviceProvisioningStatus.meshJoined([int layer = 1]) => DeviceProvisioningStatus(
        state: DeviceProvisioningState.meshJoined,
        rawStatus: 'MESH_JOINED',
        message: 'Joined mesh network (layer $layer)',
        meshLayer: layer,
      );

  factory DeviceProvisioningStatus.cloudReached() => const DeviceProvisioningStatus(
        state: DeviceProvisioningState.cloudReached,
        rawStatus: 'CLOUD_REACHED',
        message: 'Connected to SmartSwitch cloud broker',
      );

  /// Error status factories mapping blueprint failure codes
  factory DeviceProvisioningStatus.wifiAuthFailed() => const DeviceProvisioningStatus(
        state: DeviceProvisioningState.error,
        rawStatus: 'WIFI_AUTH_FAILED',
        message: 'Wi-Fi authentication failed (rejected password)',
        failureType: ProvisioningFailureType.wifiAuthFailed,
      );

  factory DeviceProvisioningStatus.routerNotFound() => const DeviceProvisioningStatus(
        state: DeviceProvisioningState.error,
        rawStatus: 'ROUTER_NOT_FOUND',
        message: 'Router not found or 5 GHz only',
        failureType: ProvisioningFailureType.routerNotFound,
      );

  factory DeviceProvisioningStatus.meshTimeout() => const DeviceProvisioningStatus(
        state: DeviceProvisioningState.error,
        rawStatus: 'MESH_TIMEOUT',
        message: 'Mesh join timeout',
        failureType: ProvisioningFailureType.meshJoinTimeout,
      );

  factory DeviceProvisioningStatus.tokenRejected() => const DeviceProvisioningStatus(
        state: DeviceProvisioningState.error,
        rawStatus: 'TOKEN_REJECTED',
        message: 'Activation token rejected or expired',
        failureType: ProvisioningFailureType.tokenRejected,
      );

  factory DeviceProvisioningStatus.alreadyBound() => const DeviceProvisioningStatus(
        state: DeviceProvisioningState.error,
        rawStatus: 'ALREADY_BOUND',
        message: 'Device is already bound to another home',
        failureType: ProvisioningFailureType.alreadyBound,
      );

  @override
  String toString() =>
      'DeviceProvisioningStatus(state: $state, raw: $rawStatus, failureType: $failureType)';
}

/// Abstract BLE provisioner interface for ESP unified provisioning.
/// Provides scanning, secure protocomm session establishment (Security 2 SRP6a),
/// Wi-Fi configuration push, custom endpoint configuration ("sw-config"),
/// and real-time status streaming.
abstract interface class BleProvisioner {
  /// Scans for nearby provisioning devices.
  Stream<BleDiscoveredDevice> scan({Duration timeout = const Duration(seconds: 10)});

  /// Connects to the given BLE advertisement.
  Future<void> connect(BleDiscoveredDevice device);

  /// Establishes an ESP-IDF Protocomm Security 2 (SRP6a) session using [proofOfPossession].
  Future<void> establishSession({required String proofOfPossession});

  /// Reads device capabilities and status from the device.
  Future<ProvisioningDeviceInfo> readDeviceInfo();

  /// Sends Wi-Fi credentials via the standard ESP provisioning config endpoint.
  Future<void> sendWifiCredentials({
    required String ssid,
    required String passphrase,
  });

  /// Sends custom configuration to [endpoint] (e.g. "sw-config") with [data].
  Future<void> sendCustomConfig({
    required String endpoint,
    required Map<String, dynamic> data,
  });

  /// Listens to real-time provisioning status updates from the device.
  Stream<DeviceProvisioningStatus> listenStatus();

  /// Disconnects and releases active BLE connection and session.
  Future<void> disconnect();
}
