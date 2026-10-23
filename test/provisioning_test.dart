import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smartswitch_app/core/errors/provisioning_error.dart';
import 'package:smartswitch_app/features/onboarding/data/token_service.dart';
import 'package:smartswitch_app/features/onboarding/domain/custom_config.dart';
import 'package:smartswitch_app/features/onboarding/domain/qr_payload.dart';
import 'package:smartswitch_app/features/onboarding/presentation/permission_service.dart';
import 'package:smartswitch_app/features/onboarding/presentation/provisioning_controller.dart';
import 'package:smartswitch_app/transport/ble_provisioner.dart';
import 'package:smartswitch_app/transport/fake_ble_provisioner.dart';

void main() {
  group('QR Code Payload Specification (SW1:<productId>:<deviceId>:<PoP>)', () {
    test('parses valid QR payload correctly', () {
      const raw = 'SW1:switch_2g:dev_9a41b2:pop_secret123';
      final payload = QrPayload.parse(raw);

      expect(payload.productId, 'switch_2g');
      expect(payload.deviceId, 'dev_9a41b2');
      expect(payload.pop, 'pop_secret123');
      expect(payload.toQrString(), raw);
    });

    test('rejects invalid schema prefix', () {
      expect(
        () => QrPayload.parse('SW2:switch_2g:dev_9a41b2:pop_secret123'),
        throwsA(isA<ProvisioningException>().having(
          (e) => e.type,
          'type',
          ProvisioningFailureType.invalidQr,
        )),
      );
    });

    test('rejects payloads with missing colons/fields', () {
      expect(
        () => QrPayload.parse('SW1:switch_2g:dev_9a41b2'),
        throwsA(isA<ProvisioningException>()),
      );
      expect(
        () => QrPayload.parse('SW1::dev_9a41b2:pop_secret123'),
        throwsA(isA<ProvisioningException>()),
      );
      expect(
        () => QrPayload.parse('SW1:switch_2g::pop_secret123'),
        throwsA(isA<ProvisioningException>()),
      );
      expect(
        () => QrPayload.parse('SW1:switch_2g:dev_9a41b2:'),
        throwsA(isA<ProvisioningException>()),
      );
    });

    test('controller parseQr throws and transitions state to failure on invalid QR', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(provisioningControllerProvider.notifier);
      expect(
        () => controller.parseQr('invalid_qr_data'),
        throwsA(isA<ProvisioningException>()),
      );

      final state = container.read(provisioningControllerProvider);
      expect(state.stage, ProvisioningStage.failure);
      expect(state.error?.type, ProvisioningFailureType.invalidQr);
    });
  });

  group('BleDiscoveredDevice deviceId matching', () {
    const target = 'dev_1234';

    test('matches exact deviceId', () {
      const dev = BleDiscoveredDevice(
        id: '00:11:22:33:44:55',
        name: 'PROV_SWITCH',
        deviceId: 'dev_1234',
      );
      expect(dev.matchesDeviceId(target), isTrue);
    });

    test('matches name containing deviceId', () {
      const dev = BleDiscoveredDevice(
        id: '00:11:22:33:44:55',
        name: 'PROV_dev_1234',
      );
      expect(dev.matchesDeviceId(target), isTrue);
    });

    test('rejects non-matching deviceId', () {
      const dev = BleDiscoveredDevice(
        id: '00:11:22:33:44:55',
        name: 'PROV_dev_other_9999',
        deviceId: 'dev_other_9999',
      );
      expect(dev.matchesDeviceId(target), isFalse);
    });
  });

  group('End-to-End Provisioning Controller with FakeBleProvisioner', () {
    late FakeBleProvisioner fakeBle;
    late MockTokenService mockToken;
    late FakePermissionService fakePermissions;
    late ProviderContainer container;

    const validQr = QrPayload(
      productId: 'switch_1g',
      deviceId: 'dev_target_01',
      pop: 'valid_pop_123',
    );

    final defaultParams = ProvisioningParams(
      wifiSsid: 'MyHomeWiFi',
      wifiPassword: 'securePassword123',
      homeId: 'h_test',
      userId: 'u_tester',
      meshId: '010203040506',
      meshApPsk: 'MeshPassword12345',
      netKeyWrapped: 'wrapped_key_material',
      cloudEndpoint: 'mqtts://iot.smartswitch.internal:8883',
      region: 'ap-south-1',
      deviceName: 'Kitchen Light',
      roomId: 'r_kitchen',
    );

    setUp(() {
      fakeBle = FakeBleProvisioner(
        availableDevices: [
          const BleDiscoveredDevice(
            id: 'AA:BB:CC:00:11:22',
            name: 'PROV_dev_target_01',
            deviceId: 'dev_target_01',
            rssi: -55,
          ),
        ],
        expectedPoP: 'valid_pop_123',
        statusEventDelay: const Duration(milliseconds: 5),
      );
      mockToken = MockTokenService();
      fakePermissions = FakePermissionService();

      container = ProviderContainer(
        overrides: [
          bleProvisionerProvider.overrideWithValue(fakeBle),
          tokenServiceProvider.overrideWithValue(mockToken),
          permissionServiceProvider.overrideWithValue(fakePermissions),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Happy Path: Complete provisioning reaches success', () async {
      final controller = container.read(provisioningControllerProvider.notifier);

      await controller.runProvisioning(
        qrPayload: validQr,
        params: defaultParams,
        scanTimeout: const Duration(milliseconds: 500),
      );

      final state = container.read(provisioningControllerProvider);
      expect(state.stage, ProvisioningStage.success);
      expect(state.error, isNull);
      expect(state.connectedDevice?.deviceId, 'dev_target_01');
      expect(state.activationToken, isNotNull);
      expect(state.currentStatus?.state, DeviceProvisioningState.cloudReached);

      // Verify FakeBle recorded correct values
      expect(fakeBle.connectedDevices.length, 1);
      expect(fakeBle.connectedDevices.first.deviceId, 'dev_target_01');
      expect(fakeBle.lastSentSsid, 'MyHomeWiFi');
      expect(fakeBle.lastSentPassphrase, 'securePassword123');
      expect(fakeBle.lastEstablishedSessionPoP, 'valid_pop_123');
      expect(fakeBle.sentCustomConfigs.length, 1);
      expect(fakeBle.sentCustomConfigs.first['endpoint'], 'sw-config');
      expect(fakeBle.isDisconnected, isTrue); // Cleaned up after completion
    });

    test('SECURITY RULE: Flow must NEVER connect to a device whose deviceId differs from QR', () async {
      // Nearby device belongs to neighbour
      fakeBle.availableDevices = [
        const BleDiscoveredDevice(
          id: '99:99:99:99:99:99',
          name: 'PROV_dev_neighbour_switch',
          deviceId: 'dev_neighbour_switch',
          rssi: -40,
        ),
      ];

      final controller = container.read(provisioningControllerProvider.notifier);

      await expectLater(
        controller.runProvisioning(
          qrPayload: validQr, // Expecting dev_target_01
          params: defaultParams,
          scanTimeout: const Duration(milliseconds: 200),
        ),
        throwsA(isA<ProvisioningException>().having(
          (e) => e.type,
          'type',
          ProvisioningFailureType.deviceNotFound,
        )),
      );

      final state = container.read(provisioningControllerProvider);
      expect(state.stage, ProvisioningStage.failure);

      // CRITICAL ASSERTION: The provisioner NEVER connected to the neighbour device!
      expect(fakeBle.connectedDevices, isEmpty);
      expect(fakeBle.isConnected, isFalse);
    });

    test('Failure path: Bluetooth permissions denied', () async {
      fakePermissions.bluetoothGranted = false;
      final controller = container.read(provisioningControllerProvider.notifier);

      await expectLater(
        controller.runProvisioning(
          qrPayload: validQr,
          params: defaultParams,
        ),
        throwsA(isA<ProvisioningException>().having(
          (e) => e.type,
          'type',
          ProvisioningFailureType.permissionDenied,
        )),
      );

      final state = container.read(provisioningControllerProvider);
      expect(state.stage, ProvisioningStage.failure);
      expect(fakeBle.connectedDevices, isEmpty);
    });

    test('Failure path: Bluetooth adapter off / scan fails', () async {
      fakeBle.shouldFailScan = true;
      final controller = container.read(provisioningControllerProvider.notifier);

      await expectLater(
        controller.runProvisioning(
          qrPayload: validQr,
          params: defaultParams,
        ),
        throwsA(isA<ProvisioningException>().having(
          (e) => e.type,
          'type',
          ProvisioningFailureType.bluetoothDisabled,
        )),
      );

      final state = container.read(provisioningControllerProvider);
      expect(state.stage, ProvisioningStage.failure);
    });

    test('Failure path: Connection fails', () async {
      fakeBle.shouldFailConnection = true;
      final controller = container.read(provisioningControllerProvider.notifier);

      await expectLater(
        controller.runProvisioning(
          qrPayload: validQr,
          params: defaultParams,
        ),
        throwsA(isA<ProvisioningException>().having(
          (e) => e.type,
          'type',
          ProvisioningFailureType.connectionFailed,
        )),
      );

      final state = container.read(provisioningControllerProvider);
      expect(state.stage, ProvisioningStage.failure);
    });

    test('Failure path: Wrong PoP / SRP6a Handshake fails (Blueprint table)', () async {
      const wrongPopQr = QrPayload(
        productId: 'switch_1g',
        deviceId: 'dev_target_01',
        pop: 'incorrect_pop_secret',
      );
      final controller = container.read(provisioningControllerProvider.notifier);

      await expectLater(
        controller.runProvisioning(
          qrPayload: wrongPopQr,
          params: defaultParams,
        ),
        throwsA(isA<ProvisioningException>().having(
          (e) => e.type,
          'type',
          ProvisioningFailureType.handshakeFailedWrongPop,
        )),
      );

      final state = container.read(provisioningControllerProvider);
      expect(state.stage, ProvisioningStage.failure);
      expect(state.error?.userMessage, "This code doesn't match the device");
      expect(state.error?.recoveryAction, 'Re-scan QR, check sticker');
    });

    test('Failure path: Device already bound (Blueprint table)', () async {
      fakeBle.customDeviceInfo = const ProvisioningDeviceInfo(
        productId: 'switch_1g',
        deviceId: 'dev_target_01',
        firmwareVersion: '1.0.0',
        isProvisioned: true, // Already provisioned!
      );

      final controller = container.read(provisioningControllerProvider.notifier);

      await expectLater(
        controller.runProvisioning(
          qrPayload: validQr,
          params: defaultParams,
        ),
        throwsA(isA<ProvisioningException>().having(
          (e) => e.type,
          'type',
          ProvisioningFailureType.alreadyBound,
        )),
      );

      final state = container.read(provisioningControllerProvider);
      expect(state.stage, ProvisioningStage.failure);
      expect(state.error?.userMessage, 'Already added to another home');
      expect(state.error?.recoveryAction, 'Owner must reset and remove it');
    });

    test('Failure path: Activation token request fails', () async {
      mockToken.shouldFail = true;
      final controller = container.read(provisioningControllerProvider.notifier);

      await expectLater(
        controller.runProvisioning(
          qrPayload: validQr,
          params: defaultParams,
        ),
        throwsA(isA<ProvisioningException>().having(
          (e) => e.type,
          'type',
          ProvisioningFailureType.tokenRequestFailed,
        )),
      );

      final state = container.read(provisioningControllerProvider);
      expect(state.stage, ProvisioningStage.failure);
    });

    test('Failure path: Status stream reports Wi-Fi password rejected (WIFI_AUTH_FAILED)', () async {
      fakeBle.customStatuses = [
        DeviceProvisioningStatus.wifiConnecting(),
        DeviceProvisioningStatus.wifiAuthFailed(),
      ];

      final controller = container.read(provisioningControllerProvider.notifier);

      await expectLater(
        controller.runProvisioning(
          qrPayload: validQr,
          params: defaultParams,
        ),
        throwsA(isA<ProvisioningException>().having(
          (e) => e.type,
          'type',
          ProvisioningFailureType.wifiAuthFailed,
        )),
      );

      final state = container.read(provisioningControllerProvider);
      expect(state.stage, ProvisioningStage.failure);
      expect(state.error?.userMessage, 'Wi-Fi password rejected');
      expect(state.error?.recoveryAction, 'Re-enter password, device keeps provisioning mode');
    });

    test('Failure path: Status stream reports Router not found (ROUTER_NOT_FOUND)', () async {
      fakeBle.customStatuses = [
        DeviceProvisioningStatus.wifiConnecting(),
        DeviceProvisioningStatus.routerNotFound(),
      ];

      final controller = container.read(provisioningControllerProvider.notifier);

      await expectLater(
        controller.runProvisioning(
          qrPayload: validQr,
          params: defaultParams,
        ),
        throwsA(isA<ProvisioningException>().having(
          (e) => e.type,
          'type',
          ProvisioningFailureType.routerNotFound,
        )),
      );

      final state = container.read(provisioningControllerProvider);
      expect(state.stage, ProvisioningStage.failure);
      expect(state.error?.userMessage, 'No 2.4 GHz network found');
      expect(state.error?.recoveryAction, 'Explain 2.4 GHz requirement');
    });

    test('Failure path: Status stream reports Mesh Join Timeout (MESH_TIMEOUT)', () async {
      fakeBle.customStatuses = [
        DeviceProvisioningStatus.wifiConnecting(),
        DeviceProvisioningStatus.wifiOk(),
        DeviceProvisioningStatus.meshTimeout(),
      ];

      final controller = container.read(provisioningControllerProvider.notifier);

      await expectLater(
        controller.runProvisioning(
          qrPayload: validQr,
          params: defaultParams,
        ),
        throwsA(isA<ProvisioningException>().having(
          (e) => e.type,
          'type',
          ProvisioningFailureType.meshJoinTimeout,
        )),
      );

      final state = container.read(provisioningControllerProvider);
      expect(state.stage, ProvisioningStage.failure);
      expect(state.error?.userMessage, "Device can't reach your other switches");
      expect(state.error?.recoveryAction, 'Move closer to an existing node, retry');
    });

    test('Failure path: Status stream reports Token Rejected / Expired (TOKEN_REJECTED)', () async {
      fakeBle.customStatuses = [
        DeviceProvisioningStatus.wifiConnecting(),
        DeviceProvisioningStatus.wifiOk(),
        DeviceProvisioningStatus.tokenRejected(),
      ];

      final controller = container.read(provisioningControllerProvider.notifier);

      await expectLater(
        controller.runProvisioning(
          qrPayload: validQr,
          params: defaultParams,
        ),
        throwsA(isA<ProvisioningException>().having(
          (e) => e.type,
          'type',
          ProvisioningFailureType.tokenRejected,
        )),
      );

      final state = container.read(provisioningControllerProvider);
      expect(state.stage, ProvisioningStage.failure);
      expect(state.error?.userMessage, 'Setup expired');
      expect(state.error?.recoveryAction, 'Fetch a new token, resend config');
    });
  });

  group('CustomConfigPayload Serialization', () {
    test('serializes custom payload to valid JSON structure for sw-config endpoint', () {
      final payload = CustomConfigPayload(
        mesh: const MeshConfig(id: '010203040506', apPsk: 'MeshPSK12345678', maxLayer: 6),
        home: const HomeConfig(id: 'h_8f21', netKeyWrapped: 'wrapped_key_blob', keyId: 1),
        activation: const ActivationConfig(
          token: 'act_token_sample',
          cloud: 'mqtts://iot.example.com:8883',
          region: 'ap-south-1',
        ),
        device: const DeviceConfig(name: 'Hall switch', roomId: 'r_hall'),
      );

      final json = payload.toJson();
      expect(json['v'], 1);
      expect(json['mesh']['id'], '010203040506');
      expect(json['mesh']['ap_psk'], 'MeshPSK12345678');
      expect(json['mesh']['max_layer'], 6);
      expect(json['home']['id'], 'h_8f21');
      expect(json['home']['net_key_wrapped'], 'wrapped_key_blob');
      expect(json['home']['key_id'], 1);
      expect(json['activation']['token'], 'act_token_sample');
      expect(json['activation']['cloud'], 'mqtts://iot.example.com:8883');
      expect(json['activation']['region'], 'ap-south-1');
      expect(json['device']['name'], 'Hall switch');
      expect(json['device']['room_id'], 'r_hall');
    });
  });
}
