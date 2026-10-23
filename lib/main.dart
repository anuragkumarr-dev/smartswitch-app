import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme.dart';
import 'domain/models/models.dart';
import 'features/onboarding/presentation/debug_provisioning_screen.dart';
import 'features/onboarding/presentation/qr_scan_screen.dart';
import 'state/devices_state.dart';
import 'state/homes_state.dart';
import 'state/mesh_topology_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  _seedInitialState(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SmartSwitchApp(),
    ),
  );
}

/// Pre-seeds mock data into Riverpod state for immediate interactive demonstration.
void _seedInitialState(ProviderContainer container) {
  // 1. Home state
  final home = Home(
    homeId: 'h_main',
    name: 'My Living Space',
    timezone: 'Asia/Kolkata',
    homeKey: List.filled(32, 7),
    meshId: '010203040506',
    meshApPassword: 'SmartMeshKey99',
  );
  container.read(homesStateProvider.notifier).addHome(home);
  container.read(homesStateProvider.notifier).setActiveHome('h_main');

  // 2. Devices state (all states: ON, OFF, Multi-gang, Offline)
  final now = DateTime.now();
  final devices = [
    Device(
      deviceId: 'dev_hall',
      homeId: 'h_main',
      roomId: 'r_living',
      name: 'Hall Chandelier',
      product: 'SW1-2G',
      gangsCount: 2,
      gatewayId: 'gw_root1',
      gangs: const [
        Gang(gangId: 'gang1', name: 'Chandelier', isOn: true),
        Gang(gangId: 'gang2', name: 'Wall Sconces', isOn: false),
      ],
      shadow: const Shadow(
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
      gangs: const [
        Gang(gangId: 'gang1', name: 'Speed Relay', isOn: false),
      ],
      shadow: const Shadow(
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
      gangs: const [
        Gang(gangId: 'gang1', name: 'Counter Light', isOn: true),
      ],
      shadow: const Shadow(
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
      gangs: const [
        Gang(gangId: 'gang1', name: 'Floodlight', isOn: false),
      ],
      shadow: const Shadow(
        ver: 95,
        online: false, // Offline state demonstration (Blueprint §4.2)
        reported: {
          'gang1': {'on': false},
        },
      ),
    ),
  ];

  container.read(devicesStateProvider.notifier).setDevices(devices);

  // 3. Mesh topology
  final meshNodes = [
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
      rssiToParent: -79,
      uptimeSeconds: 34000,
      lastSeen: now,
    ),
  ];

  container.read(meshTopologyStateProvider.notifier).updateTopology(meshNodes);
}

class SmartSwitchApp extends StatelessWidget {
  final bool usePlaceholder;
  final GoRouter? router;

  const SmartSwitchApp({
    super.key,
    this.usePlaceholder = false,
    this.router,
  });

  @override
  Widget build(BuildContext context) {
    if (usePlaceholder) {
      return MaterialApp(
        title: 'SmartSwitch',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.system,
        home: const PlaceholderHomeScreen(),
      );
    }

    return MaterialApp.router(
      title: 'SmartSwitch',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router ?? appRouter,
    );
  }
}

/// Preserved for backward test compatibility.
class PlaceholderHomeScreen extends StatelessWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SmartSwitch',
          style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 64,
              color: colorScheme.primary,
              semanticLabel: 'SmartSwitch logo placeholder',
            ),
            const SizedBox(height: Spacing.md),
            Text(
              'Welcome to SmartSwitch',
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Phase 0 — Foundation ready.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR to Provision'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const QrScanScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: Spacing.sm),
            OutlinedButton.icon(
              icon: const Icon(Icons.developer_mode),
              label: const Text('Open Provisioning Simulator'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DebugProvisioningScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
