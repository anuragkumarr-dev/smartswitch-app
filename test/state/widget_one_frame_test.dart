import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartswitch_app/domain/models/models.dart';
import 'package:smartswitch_app/state/devices_state.dart';

/// Test widget that renders a device switch toggle tied to Riverpod devicesStateProvider.
class TestSwitchCard extends ConsumerWidget {
  final String deviceId;
  final String gangId;

  const TestSwitchCard({
    super.key,
    required this.deviceId,
    required this.gangId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesStateProvider);
    final item = devices[deviceId];
    if (item == null) return const SizedBox.shrink();

    final isOn = item.effectiveGangIsOn(gangId);
    final isPending = item.isPending;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        child: Column(
          children: [
            Text(item.device.name),
            Text(isOn ? 'STATE: ON' : 'STATE: OFF'),
            if (isPending) const Text('STATUS: PENDING'),
            Switch(
              key: const Key('switch_toggle'),
              value: isOn,
              onChanged: (_) {
                ref.read(devicesStateProvider.notifier).markPending(
                      deviceId: deviceId,
                      gangId: gangId,
                      desired: !isOn,
                      commandId: 'cmd_widget_test',
                    );
              },
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('ACCEPTANCE TEST: UI state changes within one frame of a tap in widget tests', (tester) async {
    final container = ProviderContainer();
    final testDevice = Device(
      deviceId: 'dev_lamp',
      homeId: 'home_1',
      roomId: 'room_1',
      name: 'Reading Lamp',
      product: 'SW1-1G',
      gangsCount: 1,
      gatewayId: 'gw_root',
      gangs: [const Gang(gangId: 'gang1', name: 'Lamp', isOn: false)],
      shadow: const Shadow(
        ver: 50,
        online: true,
        reported: {
          'gang1': {'on': false},
        },
      ),
    );

    container.read(devicesStateProvider.notifier).setDevices([testDevice]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: TestSwitchCard(deviceId: 'dev_lamp', gangId: 'gang1'),
          ),
        ),
      ),
    );

    // Initial state: OFF, not pending
    expect(find.text('STATE: OFF'), findsOneWidget);
    expect(find.text('STATUS: PENDING'), findsNothing);

    // Tap the switch toggle
    await tester.tap(find.byKey(const Key('switch_toggle')));

    // Pump exactly ONE frame (frame 0)
    await tester.pump();

    // In the VERY FIRST FRAME: state is immediately ON and marked PENDING!
    expect(find.text('STATE: ON'), findsOneWidget,
        reason: 'UI state must change to ON within 1 frame (<16ms) of tap');
    expect(find.text('STATUS: PENDING'), findsOneWidget,
        reason: 'Pending spinner/indicator must appear within 1 frame');

    container.dispose();
  });
}
