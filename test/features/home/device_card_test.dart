import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartswitch_app/core/theme.dart';
import 'package:smartswitch_app/domain/models/models.dart';
import 'package:smartswitch_app/features/home/widgets/device_card.dart';
import 'package:smartswitch_app/state/devices_state.dart';

void main() {
  final testDevice = Device(
    deviceId: 'dev_lamp',
    homeId: 'h1',
    roomId: 'r_living',
    name: 'Reading Lamp',
    product: 'SW1-1G',
    gangsCount: 1,
    gatewayId: 'gw_root1',
    gangs: const [Gang(gangId: 'gang1', name: 'Lamp', isOn: false)],
    shadow: const Shadow(
      ver: 10,
      online: true,
      reported: {'gang1': {'on': false}},
    ),
  );

  Widget buildCard({
    required DeviceUiState state,
    Brightness brightness = Brightness.light,
    VoidCallback? onToggle,
    VoidCallback? onOfflineHelp,
    Countdown? countdown,
  }) {
    return MaterialApp(
      theme: brightness == Brightness.dark ? darkTheme : lightTheme,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 170,
            height: 150,
            child: DeviceCard(
              uiState: state,
              onToggle: onToggle,
              onOfflineHelp: onOfflineHelp,
              activeCountdown: countdown,
            ),
          ),
        ),
      ),
    );
  }

  group('DeviceCard States and Semantics (Blueprint §4.1 & §4.2)', () {
    testWidgets('Off state renders neutral card and toggle', (tester) async {
      final semantics = tester.ensureSemantics();
      final uiState = DeviceUiState(
        device: testDevice,
        shadow: testDevice.shadow,
      );

      await tester.pumpWidget(buildCard(state: uiState));
      expect(find.text('Reading Lamp'), findsOneWidget);
      expect(find.text('Turned OFF'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Verify semantics
      expect(find.bySemanticsLabel('Reading Lamp, off, switch'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('On state renders amber active styling and toggle', (tester) async {
      final semantics = tester.ensureSemantics();
      final onDevice = testDevice.copyWith(
        gangs: const [Gang(gangId: 'gang1', name: 'Lamp', isOn: true)],
        shadow: const Shadow(ver: 11, online: true, reported: {'gang1': {'on': true}}),
      );
      final uiState = DeviceUiState(
        device: onDevice,
        shadow: onDevice.shadow,
      );

      await tester.pumpWidget(buildCard(state: uiState));
      expect(find.text('Turned ON'), findsOneWidget);

      expect(find.bySemanticsLabel('Reading Lamp, on, switch'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('Pending state renders thin spinner ring', (tester) async {
      final uiState = DeviceUiState(
        device: testDevice,
        shadow: testDevice.shadow,
        pendingCommandId: 'cmd_pending_1',
        pendingGangStates: const {'gang1': true},
      );

      await tester.pumpWidget(buildCard(state: uiState));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Turned ON'), findsOneWidget); // Optimistic desired
    });

    testWidgets('Offline state disables toggle and tap triggers onOfflineHelp', (tester) async {
      final semantics = tester.ensureSemantics();
      bool offlineHelpOpened = false;

      final offlineDevice = testDevice.copyWith(
        shadow: const Shadow(ver: 10, online: false),
      );
      final uiState = DeviceUiState(
        device: offlineDevice,
        shadow: offlineDevice.shadow,
      );

      await tester.pumpWidget(
        buildCard(
          state: uiState,
          onOfflineHelp: () => offlineHelpOpened = true,
        ),
      );

      expect(find.text('Offline'), findsOneWidget);

      // Tap card
      await tester.tap(find.byType(DeviceCard));
      await tester.pump();
      expect(offlineHelpOpened, isTrue);

      // Verify semantics disabled
      expect(
        find.bySemanticsLabel('Reading Lamp, offline, switch disabled, switch'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('Shows running countdown chip when active', (tester) async {
      final uiState = DeviceUiState(
        device: testDevice,
        shadow: testDevice.shadow,
      );
      final countdown = Countdown(
        deviceId: 'dev_lamp',
        gangId: 'gang1',
        durationSeconds: 1800,
        remainingSeconds: 1500,
        action: ScheduleAction.turnOff,
        isRunning: true,
      );

      await tester.pumpWidget(
        buildCard(
          state: uiState,
          countdown: countdown,
        ),
      );

      expect(find.text('25m 00s'), findsOneWidget);
    });

    testWidgets('Tap toggle triggers onToggle callback with light haptic', (tester) async {
      bool toggled = false;
      final uiState = DeviceUiState(
        device: testDevice,
        shadow: testDevice.shadow,
      );

      await tester.pumpWidget(
        buildCard(
          state: uiState,
          onToggle: () => toggled = true,
        ),
      );

      await tester.tap(find.byKey(const Key('device_card_toggle')));
      await tester.pump();
      expect(toggled, isTrue);
    });
  });

  group('DeviceCard Golden Tests (Light & Dark Mode)', () {
    testWidgets('Golden: DeviceCard Off Light Mode', (tester) async {
      final uiState = DeviceUiState(device: testDevice, shadow: testDevice.shadow);
      await tester.pumpWidget(buildCard(state: uiState, brightness: Brightness.light));
      await expectLater(
        find.byType(DeviceCard),
        matchesGoldenFile('goldens/device_card_off_light.png'),
      );
    });

    testWidgets('Golden: DeviceCard On Dark Mode', (tester) async {
      final onDevice = testDevice.copyWith(
        gangs: const [Gang(gangId: 'gang1', name: 'Lamp', isOn: true)],
        shadow: const Shadow(ver: 11, online: true, reported: {'gang1': {'on': true}}),
      );
      final uiState = DeviceUiState(device: onDevice, shadow: onDevice.shadow);
      await tester.pumpWidget(buildCard(state: uiState, brightness: Brightness.dark));
      await expectLater(
        find.byType(DeviceCard),
        matchesGoldenFile('goldens/device_card_on_dark.png'),
      );
    });

    testWidgets('Golden: DeviceCard Offline Light Mode', (tester) async {
      final offlineDevice = testDevice.copyWith(
        shadow: const Shadow(ver: 10, online: false),
      );
      final uiState = DeviceUiState(device: offlineDevice, shadow: offlineDevice.shadow);
      await tester.pumpWidget(buildCard(state: uiState, brightness: Brightness.light));
      await expectLater(
        find.byType(DeviceCard),
        matchesGoldenFile('goldens/device_card_offline_light.png'),
      );
    });
  });
}
