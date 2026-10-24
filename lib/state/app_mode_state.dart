import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/secure_store/secure_key_store.dart';
import '../domain/models/models.dart';
import '../transport/blynk_bridge_controller.dart';
import 'auth_state.dart';
import 'devices_state.dart';
import 'mesh_topology_state.dart';

/// App data source modes:
/// - demo: Mock devices and local fake transports
/// - blynk: Real ESP-NOW hardware via Blynk Cloud V0..V16
enum AppMode {
  demo,
  blynk;

  bool get isDemo => this == AppMode.demo;
  bool get isBlynk => this == AppMode.blynk;
  String get displayName => isBlynk ? 'Blynk (real switches)' : 'Demo (fake data)';
}

/// Static service providing predictable demo data for Demo mode.
class DemoDataService {
  static List<Device> get demoDevices {
    return const [
      Device(
        deviceId: 'dev_hall',
        homeId: 'h_main',
        roomId: 'r_living',
        name: 'Hall Chandelier',
        product: 'SW1-2G',
        gangsCount: 2,
        gatewayId: 'gw_root1',
        gangs: [
          Gang(gangId: 'gang1', name: 'Chandelier', isOn: true),
          Gang(gangId: 'gang2', name: 'Wall Sconces', isOn: false),
        ],
        shadow: Shadow(
          ver: 104,
          online: true,
          reported: {
            'gang1': {'on': true},
            'gang2': {'on': false},
          },
        ),
      ),
      Device(
        deviceId: 'dev_fan',
        homeId: 'h_main',
        roomId: 'r_bed',
        name: 'Ceiling Fan',
        product: 'SW1-1G Fan',
        gangsCount: 1,
        gatewayId: 'gw_root1',
        gangs: [
          Gang(gangId: 'gang1', name: 'Speed Relay', isOn: false),
        ],
        shadow: Shadow(
          ver: 101,
          online: true,
          reported: {
            'gang1': {'on': false},
          },
        ),
      ),
      Device(
        deviceId: 'dev_kitchen',
        homeId: 'h_main',
        roomId: 'r_kitchen',
        name: 'Kitchen Lights',
        product: 'SW1-1G',
        gangsCount: 1,
        gatewayId: 'gw_root1',
        gangs: [
          Gang(gangId: 'gang1', name: 'Counter Light', isOn: true),
        ],
        shadow: Shadow(
          ver: 108,
          online: true,
          reported: {
            'gang1': {'on': true},
          },
        ),
      ),
      Device(
        deviceId: 'dev_balcony',
        homeId: 'h_main',
        roomId: 'r_balcony',
        name: 'Balcony Floodlight',
        product: 'SW1-1G',
        gangsCount: 1,
        gatewayId: 'gw_root1',
        gangs: [
          Gang(gangId: 'gang1', name: 'Floodlight', isOn: false),
        ],
        shadow: Shadow(
          ver: 95,
          online: false,
          reported: {
            'gang1': {'on': false},
          },
        ),
      ),
    ];
  }

  static List<MeshNode> get demoMeshNodes {
    final now = DateTime.now();
    return [
      MeshNode(
        deviceId: 'gw_root1',
        name: 'Hall Switch (Root)',
        roomId: 'r_living',
        role: MeshRole.root,
        layer: 1,
        childrenCount: 2,
        rssiToParent: -48,
        uptimeSeconds: 86400,
        lastSeen: now,
      ),
      MeshNode(
        deviceId: 'dev_fan',
        name: 'Ceiling Fan',
        roomId: 'r_bed',
        role: MeshRole.node,
        layer: 2,
        parentId: 'gw_root1',
        childrenCount: 1,
        rssiToParent: -56,
        uptimeSeconds: 72000,
        lastSeen: now,
      ),
      MeshNode(
        deviceId: 'dev_kitchen',
        name: 'Kitchen Lights',
        roomId: 'r_kitchen',
        role: MeshRole.node,
        layer: 2,
        parentId: 'gw_root1',
        childrenCount: 0,
        rssiToParent: -68,
        uptimeSeconds: 65000,
        lastSeen: now,
      ),
      MeshNode(
        deviceId: 'dev_balcony',
        name: 'Balcony Floodlight',
        roomId: 'r_balcony',
        role: MeshRole.node,
        layer: 3,
        parentId: 'dev_fan',
        childrenCount: 0,
        rssiToParent: -78,
        uptimeSeconds: 34000,
        lastSeen: now,
      ),
    ];
  }
}

/// State notifier managing the active application mode persistently.
class AppModeNotifier extends Notifier<AppMode> {
  SecureKeyStore? _secureStorage;

  @override
  AppMode build() {
    _secureStorage = ref.watch(secureKeyStoreProvider);
    _loadPersistedMode();
    return AppMode.demo;
  }

  Future<void> _loadPersistedMode() async {
    final SecureKeyStore storage = _secureStorage ?? ref.read(secureKeyStoreProvider);
    final savedMode = await storage.getAppMode();
    final token = await storage.getBlynkToken();
    final hasToken = token != null && token.isNotEmpty;

    if (savedMode != null) {
      state = savedMode == 'blynk' ? AppMode.blynk : AppMode.demo;
    } else if (hasToken) {
      state = AppMode.blynk;
    } else {
      state = AppMode.demo;
    }
  }

  Future<void> setMode(AppMode mode) async {
    state = mode;
    final SecureKeyStore storage = _secureStorage ?? ref.read(secureKeyStoreProvider);
    await storage.saveAppMode(mode == AppMode.blynk ? 'blynk' : 'demo');

    if (mode == AppMode.demo) {
      await ref.read(blynkTransportProvider).disconnect();
      ref.read(devicesStateProvider.notifier).setDevices(DemoDataService.demoDevices);
      ref.read(meshTopologyStateProvider.notifier).setNodes(
            nodes: DemoDataService.demoMeshNodes,
            rootGatewayId: 'gw_root1',
          );
    } else {
      await ref.read(blynkBridgeControllerProvider).initialize();
    }
  }
}

final appModeProvider = NotifierProvider<AppModeNotifier, AppMode>(AppModeNotifier.new);
