import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartswitch_app/data/api_client/api_client.dart';
import 'package:smartswitch_app/data/device_repository.dart';
import 'package:smartswitch_app/data/local_db/in_memory_local_database.dart';
import 'package:smartswitch_app/domain/models/models.dart';
import 'package:smartswitch_app/state/devices_state.dart';
import 'package:smartswitch_app/transport/cloud_transport.dart';
import 'package:smartswitch_app/transport/command_router.dart';
import 'package:smartswitch_app/transport/local_transport.dart';
import 'package:smartswitch_app/transport/mdns_service.dart';
import 'package:smartswitch_app/transport/models/command_result.dart';
import 'package:smartswitch_app/transport/models/message_envelope.dart';

void main() {
  group('DevicesState & Optimistic UI (Blueprint §3.2 & §3.6)', () {
    late ProviderContainer container;
    late DevicesNotifier notifier;
    late InMemoryLocalDatabase localDb;
    late MockApiClient apiClient;
    late DeviceRepository repo;

    final testDevice = Device(
      deviceId: 'dev_living',
      homeId: 'home_main',
      roomId: 'room_living',
      name: 'Living Room Switch',
      product: 'SW1-1G',
      gangsCount: 1,
      gatewayId: 'gw_root',
      gangs: [const Gang(gangId: 'gang1', name: 'Main Lamp', isOn: false)],
      shadow: const Shadow(
        ver: 100,
        online: true,
        reported: {
          'gang1': {'on': false},
        },
      ),
    );

    setUp(() {
      localDb = InMemoryLocalDatabase(initialDevices: [testDevice]);
      apiClient = MockApiClient(
        initialDevices: {
          'home_main': [testDevice],
        },
      );
      repo = DeviceRepository(localDatabase: localDb, apiClient: apiClient);

      container = ProviderContainer();
      notifier = container.read(devicesStateProvider.notifier);
      notifier.setRepository(repo);
      notifier.setDevices([testDevice]);
    });

    tearDown(() {
      container.dispose();
      repo.dispose();
    });

    test('ACCEPTANCE: UI state changes within one frame of a tap (same frame optimistic pending)', () {
      final initialItem = container.read(devicesStateProvider)['dev_living']!;
      expect(initialItem.effectiveGangIsOn('gang1'), isFalse);
      expect(initialItem.isPending, isFalse);

      // User taps toggle
      const commandId = 'c_tap_1';
      notifier.markPending(
        deviceId: 'dev_living',
        gangId: 'gang1',
        desired: true,
        commandId: commandId,
      );

      // Synchronously in the EXACT SAME FRAME
      final pendingItem = container.read(devicesStateProvider)['dev_living']!;
      expect(pendingItem.isPending, isTrue);
      expect(pendingItem.pendingCommandId, commandId);
      expect(pendingItem.effectiveGangIsOn('gang1'), isTrue,
          reason: 'Effective state must switch to desired immediately without waiting for network');
    });

    test('Confirmation clears pending state and commits reported state with new ver', () {
      notifier.markPending(
        deviceId: 'dev_living',
        gangId: 'gang1',
        desired: true,
        commandId: 'c_tap_2',
      );

      // Confirm arrives from Root with ver 101
      notifier.confirm(
        deviceId: 'dev_living',
        commandId: 'c_tap_2',
        ver: 101,
        reported: {
          'gang1': {'on': true},
        },
      );

      final confirmedItem = container.read(devicesStateProvider)['dev_living']!;
      expect(confirmedItem.isPending, isFalse);
      expect(confirmedItem.pendingCommandId, isNull);
      expect(confirmedItem.shadow.ver, 101);
      expect(confirmedItem.effectiveGangIsOn('gang1'), isTrue);
      expect(confirmedItem.device.gangs.first.isOn, isTrue);
    });

    test('Rollback on timeout: reverts optimistic pending back to last confirmed state', () {
      expect(container.read(devicesStateProvider)['dev_living']!.effectiveGangIsOn('gang1'), isFalse);

      // Optimistic tap
      notifier.markPending(
        deviceId: 'dev_living',
        gangId: 'gang1',
        desired: true,
        commandId: 'c_timeout_cmd',
      );
      expect(container.read(devicesStateProvider)['dev_living']!.effectiveGangIsOn('gang1'), isTrue);

      // Timeout expires on both local and cloud paths
      notifier.rollback(
        deviceId: 'dev_living',
        commandId: 'c_timeout_cmd',
        errorMessage: 'Network timeout',
      );

      final rolledBackItem = container.read(devicesStateProvider)['dev_living']!;
      expect(rolledBackItem.isPending, isFalse);
      expect(rolledBackItem.effectiveGangIsOn('gang1'), isFalse,
          reason: 'UI must revert to previous confirmed state on failure');
      expect(rolledBackItem.errorMessage, 'Network timeout');
    });

    test('Two simulated phones toggling the same device concurrently converge (Blueprint §3.6)', () async {
      // Phone A and Phone B simulate two Riverpod containers with their own Notifiers
      final containerA = ProviderContainer();
      final notifierA = containerA.read(devicesStateProvider.notifier);
      notifierA.setDevices([testDevice]);

      final containerB = ProviderContainer();
      final notifierB = containerB.read(devicesStateProvider.notifier);
      notifierB.setDevices([testDevice]);

      // Phone A taps: wants ON
      notifierA.markPending(
        deviceId: 'dev_living',
        gangId: 'gang1',
        desired: true,
        commandId: 'cmd_phone_A',
      );

      // Phone B taps: wants OFF
      notifierB.markPending(
        deviceId: 'dev_living',
        gangId: 'gang1',
        desired: false,
        commandId: 'cmd_phone_B',
      );

      // Device Root processes Phone A's command first (ver 101: ON)
      final reportA = {'gang1': {'on': true}};
      notifierA.confirm(
        deviceId: 'dev_living',
        commandId: 'cmd_phone_A',
        ver: 101,
        reported: reportA,
      );
      // Fan out to Phone B as live delta
      notifierB.applyLiveDelta(
        deviceId: 'dev_living',
        reported: reportA,
        ver: 101,
      );

      // Device Root then processes Phone B's command (ver 102: OFF)
      final reportB = {'gang1': {'on': false}};
      notifierB.confirm(
        deviceId: 'dev_living',
        commandId: 'cmd_phone_B',
        ver: 102,
        reported: reportB,
      );
      // Fan out to Phone A as live delta
      notifierA.applyLiveDelta(
        deviceId: 'dev_living',
        reported: reportB,
        ver: 102,
      );

      // Both phones must converge to identical state: OFF at ver 102!
      final stateA = containerA.read(devicesStateProvider)['dev_living']!;
      final stateB = containerB.read(devicesStateProvider)['dev_living']!;

      expect(stateA.shadow.ver, 102);
      expect(stateB.shadow.ver, 102);
      expect(stateA.effectiveGangIsOn('gang1'), isFalse);
      expect(stateB.effectiveGangIsOn('gang1'), isFalse);
      expect(stateA.isPending, isFalse);
      expect(stateB.isPending, isFalse);

      containerA.dispose();
      containerB.dispose();
    });

    test('End-to-end toggleGang with CommandRouter dispatches, updates same frame, and confirms', () async {
      // Setup mock router with instant cloud ACK
      final fakeMdns = FakeMdnsService();
      final local = LocalTransport(
        mdnsService: fakeMdns,
        homeKey: List.filled(32, 0),
      );
      final cloud = MockCloudTransport(
        startConnected: true,
        responseDelay: const Duration(milliseconds: 10),
      );

      final router = CommandRouter(
        local: local,
        cloud: cloud,
      );

      final resultFuture = notifier.toggleGang(
        deviceId: 'dev_living',
        gangId: 'gang1',
        router: router,
      );

      // Same frame check: immediately pending ON
      expect(container.read(devicesStateProvider)['dev_living']!.isPending, isTrue);
      expect(container.read(devicesStateProvider)['dev_living']!.effectiveGangIsOn('gang1'), isTrue);

      // Wait for router execution
      final result = await resultFuture;
      expect(result, CmdResult.success);

      final finalItem = container.read(devicesStateProvider)['dev_living']!;
      expect(finalItem.isPending, isFalse);
      expect(finalItem.shadow.ver, 101);
      expect(finalItem.effectiveGangIsOn('gang1'), isTrue);

      local.dispose();
      await cloud.disconnect();
    });
  });
}
