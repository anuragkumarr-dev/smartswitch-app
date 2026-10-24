import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smartswitch_app/data/local_db/in_memory_local_database.dart';
import 'package:smartswitch_app/data/secure_store/secure_key_store.dart';
import 'package:smartswitch_app/domain/models/models.dart';
import 'package:smartswitch_app/state/devices_state.dart';
import 'package:smartswitch_app/state/mesh_topology_state.dart';
import 'package:smartswitch_app/transport/blynk_bridge_controller.dart';
import 'package:smartswitch_app/transport/blynk_transport.dart';
import 'package:smartswitch_app/transport/models/blynk_node_map.dart';
import 'package:smartswitch_app/transport/models/message_envelope.dart';
import 'fake_blynk_server.dart';

void main() {
  group('Blynk Node Map Parser Tests', () {
    test('Parses V16 node map string correctly with master and peers', () {
      const raw =
          'A1B2C3D4E501;A1B2C3D4E501:0:1:-55:1,A1B2C3D4E502:1:0:-68:1,A1B2C3D4E503:2:0:-82:0';

      final map = BlynkNodeMap.parse(raw);
      expect(map.masterMac, 'A1B2C3D4E501');
      expect(map.nodesByMac.length, 3);

      final master = map.nodesByMac['A1B2C3D4E501']!;
      expect(master.pin, 0);
      expect(master.state, true);
      expect(master.rssi, -55);
      expect(master.isLive, true);
      expect(master.isMaster, true);

      final peer2 = map.nodesByMac['A1B2C3D4E502']!;
      expect(peer2.pin, 1);
      expect(peer2.state, false);
      expect(peer2.rssi, -68);
      expect(peer2.isLive, true);
      expect(peer2.isMaster, false);

      final peer3 = map.nodesByMac['A1B2C3D4E503']!;
      expect(peer3.pin, 2);
      expect(peer3.isLive, false); // offline node
    });

    test('Handles malformed or empty V16 string gracefully', () {
      final emptyMap = BlynkNodeMap.parse('');
      expect(emptyMap.masterMac, '');
      expect(emptyMap.nodesByMac, isEmpty);

      final corruptMap = BlynkNodeMap.parse('random_corrupted_string');
      expect(corruptMap.nodesByMac, isEmpty);
    });
  });

  group('BlynkCloudTransport & Fake Blynk Server Integration Tests', () {
    late FakeBlynkHttpServer server;
    late BlynkCloudTransport transport;

    setUp(() async {
      server = FakeBlynkHttpServer();
      await server.start();

      // Configure transport to talk to local fake server
      transport = BlynkCloudTransport(
        authToken: server.validToken,
        customBaseUrl: '${server.url}/external/api',
        pollingInterval: const Duration(milliseconds: 100),
      );
    });

    tearDown(() async {
      await transport.disconnect();
      await server.stop();
    });

    test('Verifies isHardwareConnected against fake server', () async {
      final isOnline = await transport.checkHardwareConnected();
      expect(isOnline, isTrue);

      server.isHardwareOnline = false;
      final isOffline = await transport.checkHardwareConnected();
      expect(isOffline, isFalse);
    });

    test('Fails on invalid auth token', () async {
      final badTransport = BlynkCloudTransport(
        authToken: 'invalid_token_99999',
        customBaseUrl: '${server.url}/external/api',
      );

      final connected = await badTransport.checkHardwareConnected();
      expect(connected, isFalse);
    });

    test('Polls V0..V16 and parses dynamic node map into state streams', () async {
      final envelopes = <MessageEnvelope>[];
      final sub = transport.incomingMessages.listen(envelopes.add);

      await transport.connect(homeId: 'h_test', brokerUrl: '');

      // Wait for poll
      await Future.delayed(const Duration(milliseconds: 350));

      expect(envelopes, isNotEmpty);
      final masterEnv = envelopes.firstWhere((e) => e.deviceId == 'A1B2C3D4E501');
      expect(masterEnv.reported?['online'], isTrue);
      expect(masterEnv.reported?['pin'], 0);

      await sub.cancel();
    });

    test('Command flow: sets desired state via update and confirms via readback', () async {
      // Prime transport with node map
      await transport.connect(homeId: 'h_test', brokerUrl: '');
      await Future.delayed(const Duration(milliseconds: 200));

      // Peer node A1B2C3D4E502 is mapped to V1
      final cmd = MessageEnvelope.cmd(
        deviceId: 'A1B2C3D4E502',
        commandId: 'c_test_01',
        desired: {'gang1': {'on': true}},
        ts: DateTime.now().millisecondsSinceEpoch,
      );

      final ack = await transport.send('h_test', 'A1B2C3D4E502', cmd);
      expect(ack, isNotNull);
      expect(ack?.type, 'ack');
      expect(ack?.reported?['gang1']['on'], isTrue);
      expect(server.pinValues[1], 1); // Pin V1 was set to 1
    });

    test('Handles Master change (pins shift at runtime) without hardcoded pins', () async {
      await transport.connect(homeId: 'h_test', brokerUrl: '');
      await Future.delayed(const Duration(milliseconds: 200));

      // Initially A1B2C3D4E501 is Master on pin 0
      expect(transport.currentNodeMap.nodesByMac['A1B2C3D4E501']?.pin, 0);

      // Simulate runtime failover / re-election in ESP-NOW firmware
      server.simulateMasterReElection();

      // Next poll updates node map
      await Future.delayed(const Duration(milliseconds: 300));

      // In new map, A1B2C3D4E502 is Master on pin 0, and A1B2C3D4E501 shifted to pin 1
      expect(transport.currentNodeMap.masterMac, 'A1B2C3D4E502');
      expect(transport.currentNodeMap.nodesByMac['A1B2C3D4E501']?.pin, 1);

      // Sending command to A1B2C3D4E501 now correctly targets pin 1!
      final cmd = MessageEnvelope.cmd(
        deviceId: 'A1B2C3D4E501',
        commandId: 'c_test_shift',
        desired: {'gang1': {'on': true}},
        ts: DateTime.now().millisecondsSinceEpoch,
      );

      final ack = await transport.send('h_test', 'A1B2C3D4E501', cmd);
      expect(ack, isNotNull);
      expect(server.pinValues[1], 1); // Targeted pin 1 dynamically
    });

    test('Rolls back command on network drop or timeout', () async {
      await transport.connect(homeId: 'h_test', brokerUrl: '');
      await Future.delayed(const Duration(milliseconds: 200));

      // Cause network drop on server
      server.dropNetwork = true;

      final cmd = MessageEnvelope.cmd(
        deviceId: 'A1B2C3D4E502',
        commandId: 'c_test_drop',
        desired: {'gang1': {'on': true}},
        ts: DateTime.now().millisecondsSinceEpoch,
      );

      final ack = await transport.send(
        'h_test',
        'A1B2C3D4E502',
        cmd,
        timeout: const Duration(milliseconds: 500),
      );

      // Null return triggers rollback
      expect(ack, isNull);
    });
  });

  group('BlynkBridgeController End-to-End Tests', () {
    late ProviderContainer container;
    late FakeBlynkHttpServer server;
    late BlynkCloudTransport transport;
    late FakeSecureKeyStore secureStorage;
    late InMemoryLocalDatabase localDb;
    late DevicesNotifier devicesNotifier;
    late MeshTopologyNotifier meshNotifier;
    late BlynkBridgeController controller;

    setUp(() async {
      server = FakeBlynkHttpServer();
      await server.start();

      secureStorage = FakeSecureKeyStore();
      await secureStorage.saveBlynkConfig(
        token: server.validToken,
        region: 'blr1',
      );

      localDb = InMemoryLocalDatabase();
      container = ProviderContainer();
      devicesNotifier = container.read(devicesStateProvider.notifier);
      meshNotifier = container.read(meshTopologyStateProvider.notifier);

      transport = BlynkCloudTransport(
        authToken: server.validToken,
        customBaseUrl: '${server.url}/external/api',
        pollingInterval: const Duration(milliseconds: 100),
      );

      controller = BlynkBridgeController(
        transport: transport,
        secureStorage: secureStorage,
        localDatabase: localDb,
        devicesNotifier: devicesNotifier,
        meshNotifier: meshNotifier,
      );
    });

    tearDown(() async {
      controller.dispose();
      await server.stop();
      container.dispose();
    });

    test('Preserves user custom device names in local DB across pin shifts', () async {
      // 1. Pre-save a user-defined custom name for MAC A1B2C3D4E502
      await localDb.saveDevices([
        const Device(
          deviceId: 'A1B2C3D4E502',
          homeId: 'h_blynk',
          roomId: 'r_bedroom',
          name: 'Master Bedroom Chandelier',
          product: 'ESP-NOW-Relay',
          gangsCount: 1,
          gatewayId: 'A1B2C3D4E501',
        ),
      ]);

      // 2. Initialize and trigger sync
      await controller.initialize();
      await Future.delayed(const Duration(milliseconds: 350));

      // 3. Verify devices notifier received custom name
      final state = container.read(devicesStateProvider);
      final chandelier = state['A1B2C3D4E502'];
      expect(chandelier, isNotNull);
      expect(chandelier?.device.name, 'Master Bedroom Chandelier');
      expect(chandelier?.device.roomId, 'r_bedroom');
      expect(chandelier?.device.capabilities.supportsSchedules, isFalse); // hidden capabilities

      // 4. Simulate Master re-election and pin shift
      server.simulateMasterReElection();
      await Future.delayed(const Duration(milliseconds: 300));

      // Custom name is still preserved!
      final stateAfterShift = container.read(devicesStateProvider);
      expect(
        stateAfterShift['A1B2C3D4E502']?.device.name,
        'Master Bedroom Chandelier',
      );
    });

    test('Populates Mesh Diagnostics with Master and peers with RSSI link qualities', () async {
      await controller.initialize();
      await Future.delayed(const Duration(milliseconds: 350));

      final meshState = container.read(meshTopologyStateProvider);
      expect(meshState.nodes.length, 3);
      expect(meshState.rootGatewayId, 'A1B2C3D4E501');

      final rootNode = meshState.nodes.firstWhere((n) => n.role == MeshRole.root);
      expect(rootNode.deviceId, 'A1B2C3D4E501');
      expect(rootNode.layer, 1);

      final peerNode = meshState.nodes.firstWhere((n) => n.deviceId == 'A1B2C3D4E502');
      expect(peerNode.role, MeshRole.node);
      expect(peerNode.parentId, 'A1B2C3D4E501');
      expect(peerNode.rssiToParent, -68);
    });
  });
}
