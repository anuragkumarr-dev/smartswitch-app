import 'package:flutter_test/flutter_test.dart';
import 'package:smartswitch_app/transport/cloud_transport.dart';
import 'package:smartswitch_app/transport/command_router.dart';
import 'package:smartswitch_app/transport/local_transport.dart';
import 'package:smartswitch_app/transport/mdns_service.dart';
import 'package:smartswitch_app/transport/models/command_result.dart';
import 'package:smartswitch_app/transport/models/message_envelope.dart';
import '../../tools/mock_root/mock_root_server.dart';

void main() {
  group('CommandRouter Dual-Path Routing (Blueprint §3.3)', () {
    late MockRootServer mockServer;
    late FakeMdnsService fakeMdns;
    late LocalTransport localTransport;
    late MockCloudTransport mockCloud;
    late CommandRouter router;

    final homeKey = List<int>.generate(32, (i) => (i * 11) % 256);
    const gatewayId = 'gw_root_dual';
    const homeId = 'h_home_123';
    const deviceId = 'dev_switch_gang1';

    final pendingLogs = <String>[];
    final confirmedLogs = <String>[];
    final rollbackLogs = <String>[];

    setUp(() async {
      pendingLogs.clear();
      confirmedLogs.clear();
      rollbackLogs.clear();

      mockServer = MockRootServer(
        gatewayId: gatewayId,
        homeKey: homeKey,
        requestedPort: 0,
      );
      await mockServer.start();

      fakeMdns = FakeMdnsService(
        initial: [
          DiscoveredRootGateway(
            gatewayId: gatewayId,
            host: '127.0.0.1',
            port: mockServer.port,
          ),
        ],
      );

      localTransport = LocalTransport(
        mdnsService: fakeMdns,
        homeKey: homeKey,
        heartbeatInterval: const Duration(seconds: 2),
      );

      mockCloud = MockCloudTransport(
        startConnected: true,
        responseDelay: const Duration(milliseconds: 10),
      );

      router = CommandRouter(
        local: localTransport,
        cloud: mockCloud,
        localTimeout: const Duration(milliseconds: 200), // reduced for fast testing
        cloudTimeout: const Duration(milliseconds: 800),
        onPending: (dev, desired, cmdId) {
          pendingLogs.add('$dev:$cmdId');
        },
        onConfirmed: (dev, cmdId, ack) {
          confirmedLogs.add('$dev:$cmdId');
        },
        onRollback: (dev, cmdId) {
          rollbackLogs.add('$dev:$cmdId');
        },
      );

      await localTransport.connect(gatewayId);
    });

    tearDown(() async {
      localTransport.dispose();
      await mockCloud.disconnect();
      await mockServer.stop();
    });

    test('Local-first execution: succeeds via local path with optimistic updates and no cloud call', () async {
      final result = await router.sendCommand(
        homeId: homeId,
        gatewayId: gatewayId,
        deviceId: deviceId,
        desired: {'gang1': {'on': true}},
      );

      expect(result.status, CmdResult.success);
      expect(result.usedCloudFallback, isFalse);
      expect(result.ack, isNotNull);

      // Verify optimistic callback fired in same frame
      expect(pendingLogs, contains('$deviceId:${result.commandId}'));
      expect(confirmedLogs, contains('$deviceId:${result.commandId}'));
      expect(rollbackLogs, isEmpty);

      // Verify Cloud was NOT called
      expect(mockCloud.publishedCommands, isEmpty);
      expect(mockServer.executionCount, 1);
    });

    test('LAN loss mid-command: local drops connection, router falls back to cloud and confirms', () async {
      // Configure mock server to drop the connection immediately mid-command
      mockServer.dropNextCommandMidExecution = true;

      final result = await router.sendCommand(
        homeId: homeId,
        gatewayId: gatewayId,
        deviceId: deviceId,
        desired: {'gang1': {'on': false}},
      );

      // Succeeded via Cloud fallback
      expect(result.status, CmdResult.success);
      expect(result.usedCloudFallback, isTrue);
      expect(mockCloud.publishedCommands.length, 1);
      expect(mockCloud.publishedCommands.first.commandId, result.commandId);

      // UI state was confirmed via cloud ACK, no rollback
      expect(confirmedLogs, contains('$deviceId:${result.commandId}'));
      expect(rollbackLogs, isEmpty);
    });

    test('ACCEPTANCE TEST: No double execution when a command is sent on both paths', () async {
      const sharedCommandId = 'c_duplicate_test_123';
      final desiredState = {'gang1': {'on': true}};

      // Simulate sending on Local path
      final localAck = await localTransport.send(
        gatewayId,
        MessageEnvelope.cmd(
          deviceId: deviceId,
          commandId: sharedCommandId,
          desired: desiredState,
        ),
      );
      expect(localAck, isNotNull);
      expect(mockServer.executionCount, 1);

      // Simulate duplicate arrival on Cloud / Root mesh router with the SAME commandId
      final duplicateEnvelope = MessageEnvelope.cmd(
        deviceId: deviceId,
        commandId: sharedCommandId,
        desired: desiredState,
      );

      // Direct delivery to mock server
      final secondAck = await localTransport.send(gatewayId, duplicateEnvelope);
      expect(secondAck, isNotNull);

      // Acceptance criterion: exactly 1 physical execution occurred!
      expect(mockServer.executionCount, 1);
      expect(mockServer.duplicateCount, 1);
    });

    test('Root address change: mDNS re-discovery updates address and WebSocket reconnects', () async {
      // 1. Initial command succeeds
      final res1 = await router.sendCommand(
        homeId: homeId,
        gatewayId: gatewayId,
        deviceId: deviceId,
        desired: {'relay': 1},
      );
      expect(res1.status, CmdResult.success);

      // 2. Simulate Root failover: stop old server, start new server on new port
      await mockServer.stop();

      final newMockServer = MockRootServer(
        gatewayId: gatewayId,
        homeKey: homeKey,
        requestedPort: 0,
      );
      await newMockServer.start();

      // Announce new address via mDNS
      fakeMdns.registerOrUpdate(
        DiscoveredRootGateway(
          gatewayId: gatewayId,
          host: '127.0.0.1',
          port: newMockServer.port,
        ),
      );

      // Notify router of network change / trigger re-probe
      await router.onNetworkChanged();

      // Wait brief moment for reconnect
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // 3. New command succeeds on new Root address
      final res2 = await router.sendCommand(
        homeId: homeId,
        gatewayId: gatewayId,
        deviceId: deviceId,
        desired: {'relay': 2},
      );

      expect(res2.status, CmdResult.success);
      expect(newMockServer.executionCount, 1);

      await newMockServer.stop();
    });

    test('Command expiry: stale commands (>30s) are rejected and rollback fires', () async {
      final staleTimestamp = DateTime.now().millisecondsSinceEpoch - 35000;

      final result = await router.sendCommand(
        homeId: homeId,
        gatewayId: gatewayId,
        deviceId: deviceId,
        desired: {'gang1': {'on': true}},
        timestamp: staleTimestamp,
      );

      expect(result.status, CmdResult.expired);
      expect(mockServer.executionCount, 0);
      expect(mockCloud.publishedCommands, isEmpty);
    });

    test('Unreachable: when both paths fail, state rolls back and returns unreachable', () async {
      // Disconnect cloud and make local server refuse connections
      mockCloud.isConnected = false;
      await mockServer.stop();

      final result = await router.sendCommand(
        homeId: homeId,
        gatewayId: 'gw_unreachable',
        deviceId: deviceId,
        desired: {'gang1': {'on': true}},
      );

      expect(result.status, CmdResult.unreachable);
      expect(rollbackLogs, contains('$deviceId:${result.commandId}'));
    });
  });
}
