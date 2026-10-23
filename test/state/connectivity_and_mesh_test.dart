import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartswitch_app/domain/models/models.dart';
import 'package:smartswitch_app/state/connectivity_state.dart';
import 'package:smartswitch_app/state/mesh_topology_state.dart';

void main() {
  group('Connectivity & Mesh Topology State Notifiers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('ConnectivityNotifier updates cloud, gateway, and BLE states', () {
      final notifier = container.read(connectivityStateProvider.notifier);
      expect(container.read(connectivityStateProvider).isCloudConnected, isFalse);

      notifier.setCloudConnected(true);
      expect(container.read(connectivityStateProvider).isCloudConnected, isTrue);

      notifier.setGatewayReachable('gw_root1', true);
      expect(container.read(connectivityStateProvider).isGatewayReachable('gw_root1'), isTrue);
      expect(container.read(connectivityStateProvider).isGatewayReachable('gw_root2'), isFalse);

      notifier.setBleConnected('dev_ble1', true);
      expect(container.read(connectivityStateProvider).bleConnectedDevices.contains('dev_ble1'), isTrue);

      notifier.setBleConnected('dev_ble1', false);
      expect(container.read(connectivityStateProvider).bleConnectedDevices.contains('dev_ble1'), isFalse);
    });

    test('MeshTopologyNotifier computes health score correctly based on RSSI and online status', () {
      final notifier = container.read(meshTopologyStateProvider.notifier);
      final now = DateTime.now();

      final rootNode = MeshNode(
        deviceId: 'gw_root1',
        name: 'Root Switch',
        roomId: 'room_hall',
        role: MeshRole.root,
        layer: 1,
        lastSeen: now,
      );

      final node1 = MeshNode(
        deviceId: 'node_1',
        name: 'Bedroom Light',
        roomId: 'room_bed',
        role: MeshRole.node,
        layer: 2,
        parentId: 'gw_root1',
        rssiToParent: -55,
        lastSeen: now,
      );

      // 1. All strong -> Green
      notifier.updateTopology([rootNode, node1]);
      var state = container.read(meshTopologyStateProvider);
      expect(state.healthScore, MeshHealth.green);
      expect(state.rootGatewayId, 'gw_root1');
      expect(state.onlineCount, 2);

      // 2. Weak links -> Amber
      final weakNode = node1.copyWith(deviceId: 'node_weak', rssiToParent: -85);
      notifier.updateTopology([rootNode, node1, weakNode]);
      state = container.read(meshTopologyStateProvider);
      expect(state.healthScore, MeshHealth.amber);

      // 3. Low online ratio or all disconnected -> Red
      final staleNode1 = node1.copyWith(lastSeen: now.subtract(const Duration(minutes: 5)));
      final staleNode2 = weakNode.copyWith(lastSeen: now.subtract(const Duration(minutes: 5)));
      notifier.updateTopology([rootNode, staleNode1, staleNode2]);
      state = container.read(meshTopologyStateProvider);
      expect(state.healthScore, MeshHealth.red);
      expect(state.onlineCount, 1);
    });
  });
}
