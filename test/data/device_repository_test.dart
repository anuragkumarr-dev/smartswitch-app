import 'package:flutter_test/flutter_test.dart';
import 'package:smartswitch_app/data/api_client/api_client.dart';
import 'package:smartswitch_app/data/device_repository.dart';
import 'package:smartswitch_app/data/local_db/in_memory_local_database.dart';
import 'package:smartswitch_app/domain/models/models.dart';

void main() {
  group('DeviceRepository & Monotonic Ver Rule (Blueprint §3.6)', () {
    late InMemoryLocalDatabase localDb;
    late MockApiClient apiClient;
    late DeviceRepository repository;

    final initialDevice = Device(
      deviceId: 'dev_1',
      homeId: 'home_a',
      roomId: 'room_1',
      name: 'Balcony Light',
      product: 'SW1-1G',
      gangsCount: 1,
      gatewayId: 'gw_root',
      gangs: [const Gang(gangId: 'gang1', name: 'Light', isOn: false)],
      shadow: const Shadow(
        ver: 10,
        online: true,
        reported: {
          'gang1': {'on': false},
        },
      ),
    );

    setUp(() {
      localDb = InMemoryLocalDatabase(initialDevices: [initialDevice]);
      apiClient = MockApiClient(
        simulatedDelay: Duration.zero,
        initialDevices: {
          'home_a': [initialDevice],
        },
      );
      repository = DeviceRepository(
        localDatabase: localDb,
        apiClient: apiClient,
      );
    });

    tearDown(() {
      repository.dispose();
    });

    test('Offline start: loads devices from cache immediately before network request', () async {
      final devices = await repository.loadFromCache('home_a');
      expect(devices.length, 1);
      expect(devices.first.deviceId, 'dev_1');
      expect(devices.first.shadow.ver, 10);
      expect(repository.currentDevices['dev_1']?.name, 'Balcony Light');
    });

    test('Monotonic ver rule: accepts deltas with ver > current and ignores stale deltas (ver <= current)', () async {
      await repository.loadFromCache('home_a');

      // 1. Delta with ver 11 > 10 should be accepted
      final accepted1 = await repository.applyLiveDelta(
        deviceId: 'dev_1',
        reported: {
          'gang1': {'on': true},
        },
        ver: 11,
      );
      expect(accepted1, isTrue);
      expect(repository.currentDevices['dev_1']?.shadow.ver, 11);
      expect(repository.currentDevices['dev_1']?.gangs.first.isOn, isTrue);

      // 2. Delayed/out-of-order delta with ver 9 <= 11 should be dropped
      final accepted2 = await repository.applyLiveDelta(
        deviceId: 'dev_1',
        reported: {
          'gang1': {'on': false},
        },
        ver: 9,
      );
      expect(accepted2, isFalse);
      // State remains ON with ver 11
      expect(repository.currentDevices['dev_1']?.shadow.ver, 11);
      expect(repository.currentDevices['dev_1']?.gangs.first.isOn, isTrue);

      // 3. Stale duplicate delta with ver 11 <= 11 should be dropped
      final accepted3 = await repository.applyLiveDelta(
        deviceId: 'dev_1',
        reported: {
          'gang1': {'on': false},
        },
        ver: 11,
      );
      expect(accepted3, isFalse);
      expect(repository.currentDevices['dev_1']?.shadow.ver, 11);
    });

    test('Reconnect reconciliation: resolves cloud snapshot with local cache without stale flicker', () async {
      await repository.loadFromCache('home_a');

      // Local had received a live delta ver 15
      await repository.applyLiveDelta(
        deviceId: 'dev_1',
        reported: {
          'gang1': {'on': true},
        },
        ver: 15,
      );

      // Cloud snapshot lagging at ver 12 (due to eventual consistency or delayed replica)
      final laggingCloudDevice = initialDevice.copyWith(
        shadow: const Shadow(
          ver: 12,
          online: true,
          reported: {
            'gang1': {'on': false},
          },
        ),
      );
      apiClient.setDevicesSnapshot('home_a', [laggingCloudDevice]);

      // Reconcile after reconnect
      final reconciled = await repository.reconcileWithSnapshot('home_a');
      expect(reconciled.first.shadow.ver, 15);
      expect(reconciled.first.gangs.first.isOn, isTrue);

      // If cloud snapshot is newer (e.g. ver 20 from another phone), it overrides
      final newerCloudDevice = initialDevice.copyWith(
        shadow: const Shadow(
          ver: 20,
          online: true,
          reported: {
            'gang1': {'on': false},
          },
        ),
      );
      apiClient.setDevicesSnapshot('home_a', [newerCloudDevice]);

      final updatedReconciled = await repository.reconcileWithSnapshot('home_a');
      expect(updatedReconciled.first.shadow.ver, 20);
      expect(updatedReconciled.first.gangs.first.isOn, isFalse);
    });
  });
}
