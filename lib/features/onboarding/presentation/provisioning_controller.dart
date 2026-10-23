import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/provisioning_error.dart';
import '../../../transport/ble_provisioner.dart';
import '../../../transport/fake_ble_provisioner.dart';
import '../data/token_service.dart';
import '../domain/custom_config.dart';
import '../domain/qr_payload.dart';
import 'permission_service.dart';

/// Active stage of the provisioning sequence.
enum ProvisioningStage {
  idle,
  checkingPermissions,
  scanningBle,
  connectingBle,
  establishingSession,
  readingDeviceInfo,
  requestingActivationToken,
  sendingWifiCredentials,
  sendingCustomConfig,
  waitingForDeviceStatus,
  success,
  failure,
}

/// Parameters passed to the onboarding flow to configure the switch.
@immutable
class ProvisioningParams {
  final String wifiSsid;
  final String wifiPassword;
  final String homeId;
  final String userId;
  final String meshId;
  final String meshApPsk;
  final String netKeyWrapped;
  final String cloudEndpoint;
  final String region;
  final String deviceName;
  final String roomId;

  const ProvisioningParams({
    required this.wifiSsid,
    required this.wifiPassword,
    this.homeId = 'h_default',
    this.userId = 'u_default',
    this.meshId = '010203040506',
    this.meshApPsk = 'SmartSwitchMeshKey123',
    this.netKeyWrapped = 'wrapped_key_payload',
    this.cloudEndpoint = 'mqtts://iot.smartswitch.internal:8883',
    this.region = 'ap-south-1',
    this.deviceName = 'Smart Switch',
    this.roomId = 'r_living',
  });
}

/// Immutable state for the provisioning engine.
@immutable
class ProvisioningState {
  final ProvisioningStage stage;
  final QrPayload? qrPayload;
  final BleDiscoveredDevice? connectedDevice;
  final ProvisioningDeviceInfo? deviceInfo;
  final String? activationToken;
  final DeviceProvisioningStatus? currentStatus;
  final ProvisioningException? error;
  final List<String> logs;

  const ProvisioningState({
    this.stage = ProvisioningStage.idle,
    this.qrPayload,
    this.connectedDevice,
    this.deviceInfo,
    this.activationToken,
    this.currentStatus,
    this.error,
    this.logs = const [],
  });

  bool get isBusy =>
      stage != ProvisioningStage.idle &&
      stage != ProvisioningStage.success &&
      stage != ProvisioningStage.failure;

  bool get isSuccess => stage == ProvisioningStage.success;
  bool get isFailure => stage == ProvisioningStage.failure;

  ProvisioningState copyWith({
    ProvisioningStage? stage,
    QrPayload? qrPayload,
    BleDiscoveredDevice? connectedDevice,
    ProvisioningDeviceInfo? deviceInfo,
    String? activationToken,
    DeviceProvisioningStatus? currentStatus,
    ProvisioningException? error,
    bool clearError = false,
    List<String>? logs,
  }) {
    return ProvisioningState(
      stage: stage ?? this.stage,
      qrPayload: qrPayload ?? this.qrPayload,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      activationToken: activationToken ?? this.activationToken,
      currentStatus: currentStatus ?? this.currentStatus,
      error: clearError ? null : (error ?? this.error),
      logs: logs ?? this.logs,
    );
  }
}

// ──────────────────────────────────────────
//  Providers
// ──────────────────────────────────────────

/// Default BLE provisioner provider. Can be overridden in tests or debug screen.
final bleProvisionerProvider = Provider<BleProvisioner>((ref) {
  return FakeBleProvisioner();
});

/// Default mock token service provider.
final tokenServiceProvider = Provider<TokenService>((ref) {
  return MockTokenService();
});

/// Default permission service provider.
final permissionServiceProvider = Provider<PermissionService>((ref) {
  return const AppPermissionService();
});

/// Notifier provider for managing the end-to-end onboarding lifecycle.
final provisioningControllerProvider =
    NotifierProvider<ProvisioningController, ProvisioningState>(
  ProvisioningController.new,
);

// ──────────────────────────────────────────
//  ProvisioningController Notifier
// ──────────────────────────────────────────

class ProvisioningController extends Notifier<ProvisioningState> {
  BleProvisioner get _bleProvisioner => ref.read(bleProvisionerProvider);
  TokenService get _tokenService => ref.read(tokenServiceProvider);
  PermissionService get _permissionService => ref.read(permissionServiceProvider);

  @override
  ProvisioningState build() {
    return const ProvisioningState();
  }

  /// Appends a message to the diagnostics logs.
  void _log(String message) {
    state = state.copyWith(logs: [...state.logs, message]);
  }

  /// Resets state back to idle.
  void reset() {
    state = const ProvisioningState();
  }

  /// Parses a raw QR payload and stores it in state.
  QrPayload parseQr(String raw) {
    try {
      final payload = QrPayload.parse(raw);
      state = state.copyWith(qrPayload: payload);
      _log('QR code parsed successfully: productId=${payload.productId}, deviceId=${payload.deviceId}');
      return payload;
    } catch (e) {
      final err = (e is ProvisioningException)
          ? e
          : ProvisioningException.invalidQr(raw, e);
      state = state.copyWith(
        stage: ProvisioningStage.failure,
        error: err,
      );
      _log('Failed to parse QR code: ${err.message}');
      throw err;
    }
  }

  /// Executes the complete provisioning flow according to Blueprint §2.2:
  /// QR -> Targeted BLE scan -> Secure Session (SRP6a) -> Device Info ->
  /// Activation Token -> Config Push -> Status Stream -> Success.
  Future<void> runProvisioning({
    required QrPayload qrPayload,
    required ProvisioningParams params,
    Duration scanTimeout = const Duration(seconds: 10),
    BleProvisioner? provisionerOverride,
    PermissionService? permissionServiceOverride,
    TokenService? tokenServiceOverride,
  }) async {
    final ble = provisionerOverride ?? _bleProvisioner;
    final permissions = permissionServiceOverride ?? _permissionService;
    final tokenSvc = tokenServiceOverride ?? _tokenService;

    state = state.copyWith(
      stage: ProvisioningStage.checkingPermissions,
      qrPayload: qrPayload,
      clearError: true,
      logs: ['Starting provisioning for device "${qrPayload.deviceId}"...'],
    );

    try {
      // 1. Permissions Check
      _log('Checking Bluetooth and Location permissions...');
      final hasPermissions =
          await permissions.checkAndRequestBluetoothPermissions();
      if (!hasPermissions) {
        throw ProvisioningException.permissionDenied('Bluetooth');
      }

      // 2. Targeted BLE Scan matching deviceId
      state = state.copyWith(stage: ProvisioningStage.scanningBle);
      _log('Initiating targeted BLE scan for deviceId: "${qrPayload.deviceId}"...');

      BleDiscoveredDevice? targetDevice;
      final completer = Completer<BleDiscoveredDevice?>();

      StreamSubscription<BleDiscoveredDevice>? scanSub;
      scanSub = ble.scan(timeout: scanTimeout).listen(
        (discovered) {
          _log('Discovered BLE advertisement: "${discovered.name}" (${discovered.id})');
          // Strict filtering: ONLY connect to the advertisement whose name or
          // manufacturer data matches the deviceId from the QR.
          if (discovered.matchesDeviceId(qrPayload.deviceId)) {
            targetDevice = discovered;
            if (!completer.isCompleted) {
              completer.complete(discovered);
            }
          } else {
            _log('Ignoring non-matching device advertisement: "${discovered.name}"');
          }
        },
        onError: (Object error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(targetDevice);
          }
        },
        cancelOnError: true,
      );

      final matched = await completer.future.timeout(
        scanTimeout,
        onTimeout: () => targetDevice,
      );
      await scanSub.cancel();

      if (matched == null) {
        throw ProvisioningException.deviceNotFound(qrPayload.deviceId);
      }

      // Strict security invariant: the flow must NEVER connect to a device
      // whose deviceId differs from the QR.
      if (!matched.matchesDeviceId(qrPayload.deviceId)) {
        throw ProvisioningException.deviceIdMismatch(
          expectedDeviceId: qrPayload.deviceId,
          discoveredDeviceId: matched.deviceId ?? matched.name,
        );
      }

      // 3. Connect over BLE
      state = state.copyWith(
        stage: ProvisioningStage.connectingBle,
        connectedDevice: matched,
      );
      _log('Connecting to target switch: ${matched.name} (${matched.id})...');
      await ble.connect(matched);
      _log('BLE connection established.');

      // 4. Secure Session (ESP-IDF Protocomm Security 2 SRP6a)
      state = state.copyWith(stage: ProvisioningStage.establishingSession);
      _log('Negotiating SRP6a Security 2 session with Proof of Possession...');
      await ble.establishSession(proofOfPossession: qrPayload.pop);
      _log('Encrypted session established successfully.');

      // 5. Read Device Info
      state = state.copyWith(stage: ProvisioningStage.readingDeviceInfo);
      _log('Reading device metadata and state...');
      final deviceInfo = await ble.readDeviceInfo();
      state = state.copyWith(deviceInfo: deviceInfo);
      _log('Device info: FW=${deviceInfo.firmwareVersion}, Bound=${deviceInfo.isProvisioned}');

      if (deviceInfo.isProvisioned) {
        throw ProvisioningException.alreadyBound();
      }

      // 6. Request single-use Activation Token from Cloud
      state = state.copyWith(stage: ProvisioningStage.requestingActivationToken);
      _log('Requesting one-time activation token for (${params.userId}, ${params.homeId}, ${qrPayload.deviceId})...');
      final token = await tokenSvc.requestActivationToken(
        userId: params.userId,
        homeId: params.homeId,
        deviceId: qrPayload.deviceId,
      );
      state = state.copyWith(activationToken: token);
      _log('Activation token received: ${token.substring(0, 10)}...');

      // 7. Send Wi-Fi credentials via standard endpoint
      state = state.copyWith(stage: ProvisioningStage.sendingWifiCredentials);
      _log('Sending Wi-Fi credentials for SSID: "${params.wifiSsid}"...');
      await ble.sendWifiCredentials(
        ssid: params.wifiSsid,
        passphrase: params.wifiPassword,
      );
      _log('Wi-Fi credentials accepted by device.');

      // 8. Send custom "sw-config" configuration
      state = state.copyWith(stage: ProvisioningStage.sendingCustomConfig);
      _log('Sending mesh, home, and activation payload to "sw-config" endpoint...');
      final customPayload = CustomConfigPayload(
        mesh: MeshConfig(
          id: params.meshId,
          apPsk: params.meshApPsk,
        ),
        home: HomeConfig(
          id: params.homeId,
          netKeyWrapped: params.netKeyWrapped,
        ),
        activation: ActivationConfig(
          token: token,
          cloud: params.cloudEndpoint,
          region: params.region,
        ),
        device: DeviceConfig(
          name: params.deviceName,
          roomId: params.roomId,
        ),
      );
      await ble.sendCustomConfig(
        endpoint: 'sw-config',
        data: customPayload.toJson(),
      );
      _log('"sw-config" payload sent successfully.');

      // 9. Stream status events from the device
      state = state.copyWith(stage: ProvisioningStage.waitingForDeviceStatus);
      _log('Awaiting device status notifications...');

      await for (final status in ble.listenStatus()) {
        state = state.copyWith(currentStatus: status);
        _log('Device status update: ${status.rawStatus} - ${status.message ?? ""}');

        if (status.state == DeviceProvisioningState.error) {
          switch (status.failureType) {
            case ProvisioningFailureType.wifiAuthFailed:
              throw ProvisioningException.wifiAuthFailed();
            case ProvisioningFailureType.routerNotFound:
              throw ProvisioningException.routerNotFound();
            case ProvisioningFailureType.meshJoinTimeout:
              throw ProvisioningException.meshJoinTimeout();
            case ProvisioningFailureType.tokenRejected:
              throw ProvisioningException.tokenRejected();
            case ProvisioningFailureType.alreadyBound:
              throw ProvisioningException.alreadyBound();
            default:
              throw ProvisioningException.unknown(
                status.message ?? 'Switch reported an unknown error (${status.rawStatus})',
              );
          }
        }

        if (status.state == DeviceProvisioningState.cloudReached) {
          _log('Device successfully reached cloud broker!');
          break;
        }
      }

      // Success reached
      state = state.copyWith(stage: ProvisioningStage.success);
      _log('Switch provisioning completed successfully!');
    } catch (e) {
      final typedError = (e is ProvisioningException)
          ? e
          : ProvisioningException.unknown('Unexpected provisioning error: $e', e);

      state = state.copyWith(
        stage: ProvisioningStage.failure,
        error: typedError,
      );
      _log('Provisioning halted with error: ${typedError.userMessage} (${typedError.message})');
      rethrow;
    } finally {
      // Always tear down BLE connection on completion or failure
      try {
        await ble.disconnect();
        _log('BLE connection closed.');
      } catch (_) {}
    }
  }
}
