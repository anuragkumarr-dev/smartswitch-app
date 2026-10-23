import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartswitch_app/data/local_db/app_database.dart';
import 'package:smartswitch_app/domain/models/models.dart';

void main() {
  group('AppDatabase (Drift SQLite persistence)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('saves and retrieves homes correctly', () async {
      final home = Home(
        homeId: 'h_drift_1',
        name: 'Beach Villa',
        timezone: 'Asia/Kolkata',
        homeKey: [10, 20, 30, 40],
        meshId: 'mesh_beach',
        meshApPassword: 'password999',
      );

      await db.saveHomes([home]);
      final retrieved = await db.getHomes();

      expect(retrieved.length, 1);
      expect(retrieved.first.homeId, 'h_drift_1');
      expect(retrieved.first.name, 'Beach Villa');
      expect(retrieved.first.homeKey, [10, 20, 30, 40]);

      final single = await db.getHome('h_drift_1');
      expect(single?.name, 'Beach Villa');
    });

    test('saves, retrieves, and updates devices and shadows', () async {
      final dev = Device(
        deviceId: 'd_drift_1',
        homeId: 'h_drift_1',
        roomId: 'r_main',
        name: 'Ceiling Fan',
        product: 'SW1-1G',
        gangsCount: 1,
        gatewayId: 'gw_root',
        gangs: [const Gang(gangId: 'gang1', name: 'Fan', isOn: false)],
        shadow: const Shadow(
          ver: 5,
          online: true,
          reported: {
            'gang1': {'on': false},
          },
        ),
      );

      await db.saveDevices([dev]);
      final devices = await db.getDevices('h_drift_1');
      expect(devices.length, 1);
      expect(devices.first.deviceId, 'd_drift_1');
      expect(devices.first.shadow.ver, 5);

      // Update shadow
      const updatedShadow = Shadow(
        ver: 6,
        online: true,
        reported: {
          'gang1': {'on': true},
        },
      );
      await db.saveShadow('d_drift_1', updatedShadow);

      final shadow = await db.getShadow('d_drift_1');
      expect(shadow?.ver, 6);
      expect(shadow?.isGangOn('gang1'), isTrue);
    });

    test('saves, retrieves, and deletes schedules', () async {
      final schedule = Schedule(
        scheduleId: 'sch_drift_1',
        deviceId: 'd_drift_1',
        gangId: 'gang1',
        hour: 6,
        minute: 0,
        repeatDays: [1, 2, 3, 4, 5],
        action: ScheduleAction.turnOn,
        syncedToDevice: true,
      );

      await db.saveSchedules('d_drift_1', [schedule]);
      final list = await db.getSchedules('d_drift_1');
      expect(list.length, 1);
      expect(list.first.formattedTime, '06:00');
      expect(list.first.syncedToDevice, isTrue);

      await db.deleteSchedule('sch_drift_1');
      final empty = await db.getSchedules('d_drift_1');
      expect(empty.isEmpty, isTrue);
    });
  });
}
