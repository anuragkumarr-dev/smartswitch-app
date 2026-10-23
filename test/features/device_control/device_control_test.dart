import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartswitch_app/core/theme.dart';
import 'package:smartswitch_app/domain/models/models.dart';
import 'package:smartswitch_app/features/device_control/presentation/device_control_screen.dart';
import 'package:smartswitch_app/features/device_control/widgets/power_button.dart';
import 'package:smartswitch_app/state/devices_state.dart';

void main() {
  group('PowerButton Widget & Golden Tests', () {
    Widget buildPowerButton({
      required bool isOn,
      bool isPending = false,
      VoidCallback? onToggle,
      Brightness brightness = Brightness.light,
    }) {
      return MaterialApp(
        theme: brightness == Brightness.dark ? darkTheme : lightTheme,
        home: Scaffold(
          body: Center(
            child: PowerButton(
              isOn: isOn,
              isPending: isPending,
              onToggle: onToggle,
            ),
          ),
        ),
      );
    }

    testWidgets('PowerButton toggles and fires onToggle callback', (tester) async {
      bool toggled = false;
      await tester.pumpWidget(
        buildPowerButton(
          isOn: false,
          onToggle: () => toggled = true,
        ),
      );

      expect(find.byType(PowerButton), findsOneWidget);
      await tester.tap(find.byType(PowerButton));
      await tester.pump();
      expect(toggled, isTrue);
    });

    testWidgets('Golden: PowerButton On Light Mode', (tester) async {
      await tester.pumpWidget(buildPowerButton(isOn: true, brightness: Brightness.light));
      await expectLater(
        find.byType(PowerButton),
        matchesGoldenFile('goldens/power_button_on_light.png'),
      );
    });

    testWidgets('Golden: PowerButton Off Dark Mode', (tester) async {
      await tester.pumpWidget(buildPowerButton(isOn: false, brightness: Brightness.dark));
      await expectLater(
        find.byType(PowerButton),
        matchesGoldenFile('goldens/power_button_off_dark.png'),
      );
    });
  });

  group('DeviceControlScreen Countdown Picker & Gang Toggles', () {
    late ProviderContainer container;

    final testDevice = Device(
      deviceId: 'dev_fan_test',
      homeId: 'h1',
      roomId: 'r_bed',
      name: 'Ceiling Fan & Lamp',
      product: 'SW1-2G',
      gangsCount: 2,
      gatewayId: 'gw_root1',
      gangs: const [
        Gang(gangId: 'gang1', name: 'Fan Relay', isOn: false),
        Gang(gangId: 'gang2', name: 'Light Relay', isOn: true),
      ],
      shadow: const Shadow(
        ver: 20,
        online: true,
        reported: {
          'gang1': {'on': false},
          'gang2': {'on': true},
        },
      ),
    );

    setUp(() {
      container = ProviderContainer();
      container.read(devicesStateProvider.notifier).setDevices([testDevice]);
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('Renders hero power button, status row, multi-gang chips, and tabs', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DeviceControlScreen(deviceId: 'dev_fan_test'),
          ),
        ),
      );

      expect(find.text('Ceiling Fan & Lamp'), findsOneWidget);
      expect(find.text('Wi-Fi ok'), findsOneWidget);
      expect(find.text('-58 dBm'), findsOneWidget);
      expect(find.text('Fan Relay'), findsOneWidget);
      expect(find.text('Light Relay'), findsOneWidget);
      expect(find.byType(PowerButton), findsOneWidget);

      // Verify tabs exist
      expect(find.text('Countdown'), findsOneWidget);
      expect(find.text('Schedules'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('Countdown wheel picker selects duration and starts countdown', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DeviceControlScreen(deviceId: 'dev_fan_test'),
          ),
        ),
      );

      // Verify CupertinoTimerPicker is present on Countdown tab
      expect(find.byType(CupertinoTimerPicker), findsOneWidget);
      expect(find.text('Start Countdown'), findsOneWidget);

      // Tap Start Countdown
      await tester.ensureVisible(find.text('Start Countdown'));
      await tester.tap(find.text('Start Countdown'));
      await tester.pumpAndSettle();

      // Countdown should now be active and show remaining banner
      expect(find.textContaining('Turning Turn OFF'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsNothing);
    });
  });
}
