import 'dart:async';
import '../core/errors/provisioning_error.dart';
import 'ble_provisioner.dart';

/// In-memory mock/fake BLE provisioner for unit testing and debug UI preview.
/// Simulates ESP-IDF unified provisioning behaviors and failures.
class FakeBleProvisioner implements BleProvisioner {
  /// Devices to emit during BLE scanning.
  List<BleDiscoveredDevice> availableDevices;

  /// Expected PoP for successful SRP6a handshake.
  /// If null, any non-empty PoP is accepted.
  String? expectedPoP;

  /// Custom device info to return.
  ProvisioningDeviceInfo? customDeviceInfo;

  /// Custom status sequence to emit.
  List<DeviceProvisioningStatus>? customStatuses;

  /// Delay between emitted status events.
  Duration statusEventDelay;

  /// Delay for scan emission.
  Duration scanDelay;

  // Failure simulation switches
  bool shouldFailScan;
  bool shouldFailConnection;
  bool shouldFailHandshake;
  bool shouldFailDeviceInfo;
  bool shouldFailWifiSend;
  bool shouldFailCustomConfigSend;

  // Recorded state for test assertions
  final List<BleDiscoveredDevice> connectedDevices = [];
  final List<Map<String, dynamic>> sentCustomConfigs = [];
  String? lastConnectedDeviceId;
  String? lastSentSsid;
  String? lastSentPassphrase;
  String? lastEstablishedSessionPoP;
  bool isConnected = false;
  bool isDisconnected = false;

  StreamController<DeviceProvisioningStatus>? _statusController;

  FakeBleProvisioner({
    List<BleDiscoveredDevice>? availableDevices,
    this.expectedPoP,
    this.customDeviceInfo,
    this.customStatuses,
    this.statusEventDelay = const Duration(milliseconds: 20),
    this.scanDelay = Duration.zero,
    this.shouldFailScan = false,
    this.shouldFailConnection = false,
    this.shouldFailHandshake = false,
    this.shouldFailDeviceInfo = false,
    this.shouldFailWifiSend = false,
    this.shouldFailCustomConfigSend = false,
  }) : availableDevices = availableDevices ?? [];

  @override
  Stream<BleDiscoveredDevice> scan({Duration timeout = const Duration(seconds: 10)}) async* {
    if (shouldFailScan) {
      throw ProvisioningException.bluetoothDisabled();
    }

    if (scanDelay > Duration.zero) {
      await Future<void>.delayed(scanDelay);
    }

    for (final device in availableDevices) {
      yield device;
    }
  }

  @override
  Future<void> connect(BleDiscoveredDevice device) async {
    if (shouldFailConnection) {
      throw ProvisioningException.connectionFailed(device.id);
    }

    connectedDevices.add(device);
    lastConnectedDeviceId = device.deviceId ?? device.name;
    isConnected = true;
    isDisconnected = false;
  }

  @override
  Future<void> establishSession({required String proofOfPossession}) async {
    if (!isConnected) {
      throw ProvisioningException.connectionFailed('none', 'Not connected to any device');
    }

    if (shouldFailHandshake) {
      throw ProvisioningException.handshakeFailedWrongPop();
    }

    if (expectedPoP != null && proofOfPossession != expectedPoP) {
      throw ProvisioningException.handshakeFailedWrongPop();
    }

    lastEstablishedSessionPoP = proofOfPossession;
  }

  @override
  Future<ProvisioningDeviceInfo> readDeviceInfo() async {
    if (shouldFailDeviceInfo) {
      throw ProvisioningException.unknown('Failed to read device info characteristic');
    }

    if (customDeviceInfo != null) {
      if (customDeviceInfo!.isProvisioned) {
        throw ProvisioningException.alreadyBound();
      }
      return customDeviceInfo!;
    }

    return ProvisioningDeviceInfo(
      productId: 'smartswitch_v1',
      deviceId: lastConnectedDeviceId ?? 'dev_default',
      firmwareVersion: '1.0.0-rc1',
      isProvisioned: false,
    );
  }

  @override
  Future<void> sendWifiCredentials({
    required String ssid,
    required String passphrase,
  }) async {
    if (shouldFailWifiSend) {
      throw ProvisioningException.wifiAuthFailed();
    }
    lastSentSsid = ssid;
    lastSentPassphrase = passphrase;
  }

  @override
  Future<void> sendCustomConfig({
    required String endpoint,
    required Map<String, dynamic> data,
  }) async {
    if (shouldFailCustomConfigSend) {
      throw ProvisioningException.unknown('Failed to send payload to custom endpoint $endpoint');
    }
    sentCustomConfigs.add({'endpoint': endpoint, 'data': data});
  }

  @override
  Stream<DeviceProvisioningStatus> listenStatus() {
    _statusController = StreamController<DeviceProvisioningStatus>.broadcast();

    final statuses = customStatuses ??
        [
          DeviceProvisioningStatus.wifiConnecting(),
          DeviceProvisioningStatus.wifiOk(),
          DeviceProvisioningStatus.meshJoined(1),
          DeviceProvisioningStatus.cloudReached(),
        ];

    // Emit statuses asynchronously
    Future<void>.microtask(() async {
      for (final status in statuses) {
        if (_statusController?.isClosed ?? true) break;
        await Future<void>.delayed(statusEventDelay);
        if (_statusController?.isClosed ?? true) break;
        _statusController?.add(status);
        if (status.state == DeviceProvisioningState.error ||
            status.state == DeviceProvisioningState.cloudReached) {
          break;
        }
      }
      await _statusController?.close();
    });

    return _statusController!.stream;
  }

  @override
  Future<void> disconnect() async {
    isConnected = false;
    isDisconnected = true;
    await _statusController?.close();
    _statusController = null;
  }
}
