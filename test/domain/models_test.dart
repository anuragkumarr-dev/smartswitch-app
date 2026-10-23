import 'package:flutter_test/flutter_test.dart';
import 'package:smartswitch_app/domain/models/models.dart';

void main() {
  group('Domain Models Immutability and Serialization', () {
    test('Home model serializes and deserializes correctly', () {
      final home = Home(
        homeId: 'h_test1',
        name: 'My Living Room',
        timezone: 'Asia/Kolkata',
        homeKey: [1, 2, 3, 4, 5],
        meshId: 'mesh01',
        meshApPassword: 'password123456',
      );

      final json = home.toJson();
      final fromJson = Home.fromJson(json);

      expect(fromJson, equals(home));
      expect(fromJson.name, 'My Living Room');
      expect(fromJson.homeKey, [1, 2, 3, 4, 5]);

      final updated = home.copyWith(name: 'Renamed Home');
      expect(updated.name, 'Renamed Home');
      expect(updated.homeId, home.homeId);
    });

    test('Device and Gang models serialize correctly', () {
      final gang1 = Gang(gangId: 'gang1', name: 'Ceiling Fan', isOn: false);
      final gang2 = Gang(gangId: 'gang2', name: 'Main Chandelier', isOn: true);

      final device = Device(
        deviceId: 'dev_8f21',
        homeId: 'h_test1',
        roomId: 'room_hall',
        name: 'Hall 2-Gang',
        product: 'SW1-2G',
        gangsCount: 2,
        gangs: [gang1, gang2],
        fwVersion: '1.2.0',
        gatewayId: 'gw_root1',
        shadow: const Shadow(
          ver: 42,
          online: true,
          reported: {
            'gang1': {'on': false},
            'gang2': {'on': true},
          },
        ),
      );

      final json = device.toJson();
      final fromJson = Device.fromJson(json);

      expect(fromJson, equals(device));
      expect(fromJson.isAnyOn, isTrue);
      expect(fromJson.isAllOn, isFalse);
      expect(fromJson.shadow.isGangOn('gang2'), isTrue);
      expect(fromJson.shadow.isGangOn('gang1'), isFalse);
    });

    test('Schedule and Countdown models calculate formatted values', () {
      final schedule = Schedule(
        scheduleId: 'sch_1',
        deviceId: 'dev_8f21',
        gangId: 'gang1',
        hour: 7,
        minute: 30,
        repeatDays: [1, 2, 3, 4, 5],
        action: ScheduleAction.turnOn,
        syncedToDevice: true,
      );

      expect(schedule.formattedTime, '07:30');
      expect(schedule.action.displayName, 'Turn ON');

      final schJson = schedule.toJson();
      expect(Schedule.fromJson(schJson), equals(schedule));

      final countdown = Countdown(
        deviceId: 'dev_8f21',
        gangId: 'gang1',
        durationSeconds: 3600,
        remainingSeconds: 3545,
        action: ScheduleAction.turnOff,
        isRunning: true,
      );

      expect(countdown.formattedRemaining, '0h 59m');
      final cdJson = countdown.toJson();
      expect(Countdown.fromJson(cdJson), equals(countdown));
    });

    test('MeshNode links map correctly to LinkQuality categories', () {
      final strongNode = MeshNode(
        deviceId: 'node_1',
        name: 'Kitchen Node',
        roomId: 'r_kitchen',
        role: MeshRole.node,
        layer: 2,
        parentId: 'gw_root1',
        rssiToParent: -55,
        lastSeen: DateTime.now(),
      );
      expect(strongNode.linkQuality, LinkQuality.excellent);

      final fairNode = strongNode.copyWith(rssiToParent: -68);
      expect(fairNode.linkQuality, LinkQuality.fair);

      final weakNode = strongNode.copyWith(rssiToParent: -80);
      expect(weakNode.linkQuality, LinkQuality.weak);
    });
  });
}
