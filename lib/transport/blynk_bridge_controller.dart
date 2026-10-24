import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_db/local_database.dart';
import '../data/secure_store/secure_key_store.dart';
import '../domain/models/models.dart';
import '../state/devices_state.dart';
import '../state/mesh_topology_state.dart';
import 'blynk_transport.dart';
import 'models/blynk_node_map.dart';
import 'models/message_envelope.dart';

/// Provider for the Blynk prototype configuration and transport bridge.
final blynkTransportProvider = Provider<BlynkCloudTransport>((ref) {
  final transport = BlynkCloudTransport(authToken: '');
  ref.onDispose(() {
    transport.disconnect();
  });
  return transport;
});

/// Bridge controller synchronizing Blynk V16 node map with:
/// 1. Drift Local Database (preserving user-edited device names and rooms by MAC)
/// 2. [DevicesNotifier] (emitting Device and Shadow updates)
/// 3. [MeshTopologyState] (displaying Master + peers with RSSI link quality)
class BlynkBridgeController {
  final BlynkCloudTransport transport;
  final SecureKeyStore secureStorage;
  final AppLocalDatabase localDatabase;
  final DevicesNotifier devicesNotifier;
  final MeshTopologyNotifier meshNotifier;
  final String homeId;

  StreamSubscription? _msgSub;

  BlynkBridgeController({
    required this.transport,
    required this.secureStorage,
    required this.localDatabase,
    required this.devicesNotifier,
    required this.meshNotifier,
    this.homeId = 'h_blynk',
  }) {
    transport.onNodesUpdated = _handleNodesUpdated;
    _msgSub = transport.incomingMessages.listen(_handleIncomingMessage);
  }

  void dispose() {
    _msgSub?.cancel();
    transport.disconnect();
  }

  /// Initializes the bridge from secure storage token and starts connection.
  Future<bool> initialize() async {
    final token = await secureStorage.getBlynkToken();
    final region = (await secureStorage.getBlynkRegion()) ?? 'blr1';

    if (token != null && token.isNotEmpty) {
      transport.updateCredentials(token: token, region: region);
      return transport.connect(homeId: homeId, brokerUrl: '');
    }
    return false;
  }

  /// Sets credentials in secure storage and reconnects.
  Future<bool> configure({required String token, String region = 'blr1'}) async {
    await secureStorage.saveBlynkConfig(token: token, region: region);
    transport.updateCredentials(token: token, region: region);
    return transport.connect(homeId: homeId, brokerUrl: '');
  }

  /// Clears Blynk credentials and stops poller.
  Future<void> clearConfig() async {
    await secureStorage.clearBlynkConfig();
    await transport.disconnect();
  }

  /// Handles incoming MessageEnvelope.state emissions from poller.
  void _handleIncomingMessage(MessageEnvelope envelope) {
    if (envelope.type == 'state' && envelope.reported != null) {
      devicesNotifier.applyLiveDelta(
        deviceId: envelope.deviceId,
        reported: envelope.reported!,
        ver: envelope.ver ?? 1,
      );
    }
  }

  /// Invoked whenever V16 node map is parsed.
  /// Reconciles nodes with Drift database by MAC and updates UI notifiers.
  Future<void> _handleNodesUpdated(
      BlynkNodeMap nodeMap, Map<int, int> rawPinStates) async {
    if (nodeMap.nodesByMac.isEmpty) return;

    // Load existing cached devices from Drift DB to preserve custom user names & rooms
    final cachedDevices = await localDatabase.getDevices(homeId);
    final cachedMap = {for (final d in cachedDevices) d.deviceId: d};

    final updatedDevices = <Device>[];
    final meshNodes = <MeshNode>[];

    for (final entry in nodeMap.nodesByMac.values) {
      final mac = entry.mac;
      final existing = cachedMap[mac];

      // Default name: "ESP-NOW Master" or "Switch <MAC-suffix>"
      final defaultName = entry.isMaster
          ? 'ESP-NOW Master'
          : 'Switch ${mac.substring(mac.length - 4)}';

      final displayName = existing?.name ?? defaultName;
      final roomId = existing?.roomId ?? (entry.isMaster ? 'r_living' : 'r_default');

      final pinVal = rawPinStates[entry.pin] ?? (entry.state ? 1 : 0);
      final isOn = pinVal == 1;

      final device = Device(
        deviceId: mac,
        homeId: homeId,
        roomId: roomId,
        name: displayName,
        product: 'ESP-NOW-Relay',
        gangsCount: 1,
        gangs: [Gang(gangId: 'gang1', name: displayName, isOn: isOn)],
        gatewayId: nodeMap.masterMac,
        fwVersion: 'blynk-1.0',
        capabilities: DeviceCapabilities.blynkBasic, // On/off & online only!
        shadow: Shadow(
          reported: {
            'gang1': {'on': isOn},
            'online': entry.isLive,
            'rssi': entry.rssi,
            'pin': entry.pin,
            'isMaster': entry.isMaster,
          },
          ver: existing?.shadow.ver ?? 1,
          online: entry.isLive,
        ),
      );

      updatedDevices.add(device);

      // Create MeshNode for topology screen
      meshNodes.add(
        MeshNode(
          deviceId: mac,
          name: displayName,
          roomId: roomId,
          role: entry.isMaster ? MeshRole.root : MeshRole.node,
          layer: entry.isMaster ? 1 : 2,
          parentId: entry.isMaster ? null : nodeMap.masterMac,
          rssiToParent: entry.rssi,
          lastSeen: DateTime.now(),
        ),
      );
    }

    // Persist in local Drift DB so names and rooms survive pin shifts and Master re-election
    await localDatabase.saveDevices(updatedDevices);

    // Update state layers
    devicesNotifier.setDevices(updatedDevices);

    // Update Mesh Diagnostics state
    meshNotifier.setNodes(
      nodes: meshNodes,
      rootGatewayId: nodeMap.masterMac,
    );
  }
}
