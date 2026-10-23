import 'dart:async';
import 'package:flutter/services.dart';
import '../core/errors/provisioning_error.dart';
import 'ble_provisioner.dart';

/// Platform channel stub for bridging Espressif's native iOS/Android provisioning SDKs.
/// Note: Native Android/iOS implementation will be completed in later phases.
class PlatformChannelBleProvisioner implements BleProvisioner {
  static const MethodChannel _methodChannel =
      MethodChannel('com.example.smartswitch/esp_provisioning');

  static const EventChannel _scanEventChannel =
      EventChannel('com.example.smartswitch/esp_provisioning_scan');

  static const EventChannel _statusEventChannel =
      EventChannel('com.example.smartswitch/esp_provisioning_status');

  @override
  Stream<BleDiscoveredDevice> scan({Duration timeout = const Duration(seconds: 10)}) {
    try {
      return _scanEventChannel.receiveBroadcastStream({
        'timeoutMs': timeout.inMilliseconds,
      }).map((dynamic event) {
        final map = Map<String, dynamic>.from(event as Map);
        return BleDiscoveredDevice(
          id: map['id'] as String,
          name: map['name'] as String? ?? '',
          deviceId: map['deviceId'] as String?,
          rssi: map['rssi'] as int? ?? -70,
          serviceUuids: (map['serviceUuids'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
        );
      }).handleError((Object error) {
        if (error is PlatformException) {
          if (error.code == 'BLUETOOTH_DISABLED') {
            throw ProvisioningException.bluetoothDisabled();
          }
          if (error.code == 'PERMISSION_DENIED') {
            throw ProvisioningException.permissionDenied(error.message ?? 'Bluetooth');
          }
        }
        throw ProvisioningException.unknown('Native BLE scan error: $error');
      });
    } on MissingPluginException catch (e) {
      // Stub behavior when running without native code attached
      return Stream.error(
        ProvisioningException.unknown('Native Espressif BLE plugin not linked: $e'),
      );
    }
  }

  @override
  Future<void> connect(BleDiscoveredDevice device) async {
    try {
      await _methodChannel.invokeMethod<void>('connect', {
        'id': device.id,
        'name': device.name,
        'deviceId': device.deviceId,
      });
    } on PlatformException catch (e) {
      throw ProvisioningException.connectionFailed(device.id, e.message);
    } on MissingPluginException {
      throw ProvisioningException.unknown(
        'Native platform channel stub: connect not implemented natively yet',
      );
    }
  }

  @override
  Future<void> establishSession({required String proofOfPossession}) async {
    try {
      await _methodChannel.invokeMethod<void>('establishSession', {
        'pop': proofOfPossession,
      });
    } on PlatformException catch (e) {
      if (e.code == 'WRONG_POP' || e.code == 'HANDSHAKE_FAILED') {
        throw ProvisioningException.handshakeFailedWrongPop(e.message);
      }
      throw ProvisioningException.unknown('Session establishment error: ${e.message}');
    } on MissingPluginException {
      throw ProvisioningException.unknown(
        'Native platform channel stub: establishSession not implemented natively yet',
      );
    }
  }

  @override
  Future<ProvisioningDeviceInfo> readDeviceInfo() async {
    try {
      final res = await _methodChannel.invokeMapMethod<String, dynamic>('readDeviceInfo');
      if (res == null) {
        throw ProvisioningException.unknown('Null device info response from native SDK');
      }

      final isProvisioned = res['isProvisioned'] as bool? ?? false;
      if (isProvisioned) {
        throw ProvisioningException.alreadyBound();
      }

      return ProvisioningDeviceInfo(
        productId: res['productId'] as String? ?? 'smartswitch_v1',
        deviceId: res['deviceId'] as String? ?? '',
        firmwareVersion: res['firmwareVersion'] as String? ?? '1.0.0',
        isProvisioned: isProvisioned,
        capabilities: (res['capabilities'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
    } on PlatformException catch (e) {
      if (e.code == 'ALREADY_BOUND') {
        throw ProvisioningException.alreadyBound(e.message);
      }
      throw ProvisioningException.unknown('Failed to read device info: ${e.message}');
    } on MissingPluginException {
      throw ProvisioningException.unknown(
        'Native platform channel stub: readDeviceInfo not implemented natively yet',
      );
    }
  }

  @override
  Future<void> sendWifiCredentials({
    required String ssid,
    required String passphrase,
  }) async {
    try {
      await _methodChannel.invokeMethod<void>('sendWifiCredentials', {
        'ssid': ssid,
        'passphrase': passphrase,
      });
    } on PlatformException catch (e) {
      if (e.code == 'WIFI_AUTH_FAILED') {
        throw ProvisioningException.wifiAuthFailed(e.message);
      }
      if (e.code == 'ROUTER_NOT_FOUND') {
        throw ProvisioningException.routerNotFound(e.message);
      }
      throw ProvisioningException.unknown('Wi-Fi config error: ${e.message}');
    } on MissingPluginException {
      throw ProvisioningException.unknown(
        'Native platform channel stub: sendWifiCredentials not implemented natively yet',
      );
    }
  }

  @override
  Future<void> sendCustomConfig({
    required String endpoint,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _methodChannel.invokeMethod<void>('sendCustomConfig', {
        'endpoint': endpoint,
        'data': data,
      });
    } on PlatformException catch (e) {
      throw ProvisioningException.unknown(
        'Failed to send custom config to $endpoint: ${e.message}',
      );
    } on MissingPluginException {
      throw ProvisioningException.unknown(
        'Native platform channel stub: sendCustomConfig not implemented natively yet',
      );
    }
  }

  @override
  Stream<DeviceProvisioningStatus> listenStatus() {
    try {
      return _statusEventChannel.receiveBroadcastStream().map((dynamic event) {
        if (event is String) {
          return _mapStatusString(event);
        } else if (event is Map) {
          final map = Map<String, dynamic>.from(event);
          final raw = map['status'] as String? ?? 'UNKNOWN';
          return _mapStatusString(raw, message: map['message'] as String?);
        }
        return const DeviceProvisioningStatus(
          state: DeviceProvisioningState.error,
          rawStatus: 'UNKNOWN_FORMAT',
        );
      });
    } on MissingPluginException {
      return Stream.error(
        ProvisioningException.unknown(
          'Native platform channel stub: listenStatus not implemented natively yet',
        ),
      );
    }
  }

  DeviceProvisioningStatus _mapStatusString(String raw, {String? message}) {
    switch (raw.toUpperCase()) {
      case 'WIFI_CONNECTING':
        return DeviceProvisioningStatus.wifiConnecting();
      case 'WIFI_OK':
        return DeviceProvisioningStatus.wifiOk();
      case 'MESH_JOINED':
        return DeviceProvisioningStatus.meshJoined(1);
      case 'CLOUD_REACHED':
        return DeviceProvisioningStatus.cloudReached();
      case 'WIFI_AUTH_FAILED':
        return DeviceProvisioningStatus.wifiAuthFailed();
      case 'ROUTER_NOT_FOUND':
        return DeviceProvisioningStatus.routerNotFound();
      case 'MESH_TIMEOUT':
        return DeviceProvisioningStatus.meshTimeout();
      case 'TOKEN_REJECTED':
        return DeviceProvisioningStatus.tokenRejected();
      case 'ALREADY_BOUND':
        return DeviceProvisioningStatus.alreadyBound();
      default:
        return DeviceProvisioningStatus(
          state: DeviceProvisioningState.error,
          rawStatus: raw,
          message: message ?? 'Unknown device status: $raw',
          failureType: ProvisioningFailureType.unknown,
        );
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _methodChannel.invokeMethod<void>('disconnect');
    } catch (_) {
      // Best-effort teardown
    }
  }
}
