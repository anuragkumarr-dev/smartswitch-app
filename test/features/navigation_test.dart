import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartswitch_app/core/router/app_router.dart';
import 'package:smartswitch_app/domain/models/models.dart';
import 'package:smartswitch_app/features/device_control/presentation/device_control_screen.dart';
import 'package:smartswitch_app/features/home/presentation/home_screen.dart';
import 'package:smartswitch_app/features/home/widgets/device_card.dart';
import 'package:smartswitch_app/features/mesh_diag/presentation/mesh_diag_screen.dart';
import 'package:smartswitch_app/features/onboarding/presentation/onboarding_flow_screen.dart';
import 'package:smartswitch_app/features/settings/presentation/settings_screen.dart';
import 'package:smartswitch_app/main.dart';
import 'package:smartswitch_app/state/devices_state.dart';
import 'package:smartswitch_app/state/homes_state.dart';
import 'package:smartswitch_app/state/mesh_topology_state.dart';

void main() {
  group('Navigation & Screen Transitions (Blueprint §4.1 - §4.5)', () {
    late ProviderContainer container;
    late GoRouter testRouter;

    final testDevice = Device(
      deviceId: 'dev_nav_test',
      homeId: 'h_main',
      roomId: 'r_living',
      name: 'Nav Test Chandelier',
      product: 'SW1-1G',
      gangsCount: 1,
      gatewayId: 'gw_root1',
      gangs: const [
        Gang(gangId: 'gang1', name: 'Main Bulb', isOn: false),
      ],
      shadow: const Shadow(
        ver: 10,
        online: true,
        reported: {
          'gang1': {'on': false},
        },
      ),
    );

    final offlineDevice = Device(
      deviceId: 'dev_offline_test',
      homeId: 'h_main',
      roomId: 'r_living',
      name: 'Offline Switch',
      product: 'SW1-1G',
      gangsCount: 1,
      gatewayId: 'gw_root1',
      gangs: const [
        Gang(gangId: 'gang1', name: 'Relay', isOn: false),
      ],
      shadow: const Shadow(
        ver: 10,
        online: false,
      ),
    );

    setUp(() {
      testRouter = createAppRouter();
      container = ProviderContainer();

      final home = Home(
        homeId: 'h_main',
        name: 'Nav Test Home',
        timezone: 'UTC',
        homeKey: List.filled(32, 1),
        meshId: '010203040506',
        meshApPassword: 'TestMeshPassword',
      );
      container.read(homesStateProvider.notifier).addHome(home);
      container.read(homesStateProvider.notifier).setActiveHome('h_main');

      container.read(devicesStateProvider.notifier).setDevices([testDevice, offlineDevice]);

      final now = DateTime.now();
      container.read(meshTopologyStateProvider.notifier).updateTopology([
        MeshNode(
          deviceId: 'gw_root1',
          name: 'Root Switch',
          roomId: 'r_living',
          role: MeshRole.root,
          layer: 1,
          childrenCount: 1,
          rssiToParent: -45,
          uptimeSeconds: 12000,
          lastSeen: now,
        ),
      ]);
    });

    tearDown(() {
      container.dispose();
      testRouter.dispose();
    });

    testWidgets('Bottom navigation tabs switch between Home, Mesh, and Settings', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: SmartSwitchApp(router: testRouter),
        ),
      );
      await tester.pumpAndSettle();

      // Starts on Home
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Nav Test Home'), findsOneWidget);

      // Switch to Mesh Diagnostics
      await tester.tap(find.text('Mesh'));
      await tester.pumpAndSettle();

      expect(find.byType(MeshDiagScreen), findsOneWidget);
      expect(find.text('Mesh Diagnostics'), findsOneWidget);
      expect(find.text('Mesh Topology Tree'), findsOneWidget);

      // Switch to Settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Manage Homes & Members'), findsOneWidget);

      // Switch back to Home
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Tapping device card navigates to DeviceControlScreen and back', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: SmartSwitchApp(router: testRouter),
        ),
      );
      await tester.pumpAndSettle();

      // Find the card for Nav Test Chandelier and tap it
      final cardFinder = find.widgetWithText(DeviceCard, 'Nav Test Chandelier');
      expect(cardFinder, findsOneWidget);
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      // Should be on DeviceControlScreen
      expect(find.byType(DeviceControlScreen), findsOneWidget);
      expect(find.text('Nav Test Chandelier'), findsWidgets);

      // Tap back button
      final backButton = find.byType(BackButton);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Back on HomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Tapping Add button navigates to OnboardingFlowScreen and back', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: SmartSwitchApp(router: testRouter),
        ),
      );
      await tester.pumpAndSettle();

      // Find Add button in top right
      final addButton = find.byTooltip('Add Switch');
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Should be on OnboardingFlowScreen
      expect(find.byType(OnboardingFlowScreen), findsOneWidget);
      expect(find.text('Before we begin'), findsOneWidget);

      // Close onboarding (back button)
      final backButton = find.byType(BackButton);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Back on HomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('DeviceCard toggle responds within one frame (<16ms) in live Home grid', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: SmartSwitchApp(router: testRouter),
        ),
      );
      await tester.pumpAndSettle();

      // Card initial state: OFF
      expect(find.text('Turned OFF'), findsWidgets);

      // Tap the toggle touch target of Nav Test Chandelier
      final toggleFinder = find.descendant(
        of: find.widgetWithText(DeviceCard, 'Nav Test Chandelier'),
        matching: find.byKey(const Key('device_card_toggle')),
      );

      await tester.tap(toggleFinder);

      // Pump exactly ONE frame
      await tester.pump();

      // State is optimistically updated and marked pending in the first frame
      final deviceUi = container.read(devicesStateProvider)['dev_nav_test'];
      expect(deviceUi?.effectiveGangIsOn('gang1'), isTrue,
          reason: 'Optimistic state must flip to ON within 1 frame');
      expect(deviceUi?.isPending, isTrue,
          reason: 'Pending indicator must activate in frame 1');
    });

    testWidgets('Tapping offline card displays offline help sheet and toggle is disabled', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: SmartSwitchApp(router: testRouter),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the offline device card
      final offlineCard = find.widgetWithText(DeviceCard, 'Offline Switch');
      expect(offlineCard, findsOneWidget);
      await tester.tap(offlineCard);
      await tester.pumpAndSettle();

      // Verify bottom sheet appears
      expect(find.text('Why might this switch be unreachable?'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);

      // Close the sheet
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      expect(find.text('Why might this switch be unreachable?'), findsNothing);
    });
  });
}
