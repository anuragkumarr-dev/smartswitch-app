import 'dart:convert';
import 'package:drift/drift.dart';
import '../../domain/models/models.dart';
import 'local_database.dart';

part 'app_database.g.dart';

class CachedHomes extends Table {
  TextColumn get homeId => text()();
  TextColumn get name => text()();
  TextColumn get timezone => text()();
  BlobColumn get homeKey => blob()();
  TextColumn get meshId => text()();
  TextColumn get meshApPassword => text()();

  @override
  Set<Column> get primaryKey => {homeId};
}

class CachedRooms extends Table {
  TextColumn get roomId => text()();
  TextColumn get homeId => text()();
  TextColumn get name => text()();
  IntColumn get orderIndex => integer()();

  @override
  Set<Column> get primaryKey => {roomId};
}

class CachedDevices extends Table {
  TextColumn get deviceId => text()();
  TextColumn get homeId => text()();
  TextColumn get roomId => text()();
  TextColumn get name => text()();
  TextColumn get product => text()();
  IntColumn get gangsCount => integer()();
  TextColumn get gangsJson => text()();
  TextColumn get fwVersion => text()();
  TextColumn get gatewayId => text()();

  @override
  Set<Column> get primaryKey => {deviceId};
}

class CachedShadows extends Table {
  TextColumn get deviceId => text()();
  TextColumn get desiredJson => text()();
  TextColumn get reportedJson => text()();
  IntColumn get ver => integer()();
  BoolColumn get online => boolean()();

  @override
  Set<Column> get primaryKey => {deviceId};
}

class CachedSchedules extends Table {
  TextColumn get scheduleId => text()();
  TextColumn get deviceId => text()();
  TextColumn get gangId => text()();
  IntColumn get hour => integer()();
  IntColumn get minute => integer()();
  TextColumn get repeatDaysJson => text()();
  TextColumn get action => text()();
  BoolColumn get isEnabled => boolean()();
  BoolColumn get syncedToDevice => boolean()();

  @override
  Set<Column> get primaryKey => {scheduleId};
}

@DriftDatabase(tables: [
  CachedHomes,
  CachedRooms,
  CachedDevices,
  CachedShadows,
  CachedSchedules,
])
class AppDatabase extends _$AppDatabase implements AppLocalDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  Future<void> init() async {}

  @override
  Future<void> saveHomes(List<Home> homes) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(
        cachedHomes,
        homes.map(
          (h) => CachedHomesCompanion.insert(
            homeId: h.homeId,
            name: h.name,
            timezone: h.timezone,
            homeKey: Uint8List.fromList(h.homeKey),
            meshId: h.meshId,
            meshApPassword: h.meshApPassword,
          ),
        ),
      );
    });
  }

  @override
  Future<List<Home>> getHomes() async {
    final rows = await select(cachedHomes).get();
    return rows
        .map(
          (r) => Home(
            homeId: r.homeId,
            name: r.name,
            timezone: r.timezone,
            homeKey: r.homeKey,
            meshId: r.meshId,
            meshApPassword: r.meshApPassword,
          ),
        )
        .toList();
  }

  @override
  Future<Home?> getHome(String homeId) async {
    final row = await (select(cachedHomes)..where((t) => t.homeId.equals(homeId)))
        .getSingleOrNull();
    if (row == null) return null;
    return Home(
      homeId: row.homeId,
      name: row.name,
      timezone: row.timezone,
      homeKey: row.homeKey,
      meshId: row.meshId,
      meshApPassword: row.meshApPassword,
    );
  }

  @override
  Future<void> saveRooms(List<Room> rooms) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(
        cachedRooms,
        rooms.map(
          (r) => CachedRoomsCompanion.insert(
            roomId: r.roomId,
            homeId: r.homeId,
            name: r.name,
            orderIndex: r.order,
          ),
        ),
      );
    });
  }

  @override
  Future<List<Room>> getRooms(String homeId) async {
    final rows = await (select(cachedRooms)
          ..where((t) => t.homeId.equals(homeId))
          ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
        .get();
    return rows
        .map(
          (r) => Room(
            roomId: r.roomId,
            homeId: r.homeId,
            name: r.name,
            order: r.orderIndex,
          ),
        )
        .toList();
  }

  @override
  Future<void> saveDevices(List<Device> devices) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(
        cachedDevices,
        devices.map(
          (d) => CachedDevicesCompanion.insert(
            deviceId: d.deviceId,
            homeId: d.homeId,
            roomId: d.roomId,
            name: d.name,
            product: d.product,
            gangsCount: d.gangsCount,
            gangsJson: jsonEncode(d.gangs.map((g) => g.toJson()).toList()),
            fwVersion: d.fwVersion,
            gatewayId: d.gatewayId,
          ),
        ),
      );
      b.insertAllOnConflictUpdate(
        cachedShadows,
        devices.map(
          (d) => CachedShadowsCompanion.insert(
            deviceId: d.deviceId,
            desiredJson: jsonEncode(d.shadow.desired),
            reportedJson: jsonEncode(d.shadow.reported),
            ver: d.shadow.ver,
            online: d.shadow.online,
          ),
        ),
      );
    });
  }

  @override
  Future<List<Device>> getDevices(String homeId) async {
    final deviceRows = await (select(cachedDevices)..where((t) => t.homeId.equals(homeId))).get();
    final result = <Device>[];

    for (final d in deviceRows) {
      final shadow = await getShadow(d.deviceId) ?? const Shadow();
      final gangsList = (jsonDecode(d.gangsJson) as List<dynamic>)
          .map((e) => Gang.fromJson(e as Map<String, dynamic>))
          .toList();

      result.add(
        Device(
          deviceId: d.deviceId,
          homeId: d.homeId,
          roomId: d.roomId,
          name: d.name,
          product: d.product,
          gangsCount: d.gangsCount,
          gangs: gangsList,
          fwVersion: d.fwVersion,
          gatewayId: d.gatewayId,
          shadow: shadow,
        ),
      );
    }
    return result;
  }

  @override
  Future<Device?> getDevice(String deviceId) async {
    final d = await (select(cachedDevices)..where((t) => t.deviceId.equals(deviceId)))
        .getSingleOrNull();
    if (d == null) return null;

    final shadow = await getShadow(d.deviceId) ?? const Shadow();
    final gangsList = (jsonDecode(d.gangsJson) as List<dynamic>)
        .map((e) => Gang.fromJson(e as Map<String, dynamic>))
        .toList();

    return Device(
      deviceId: d.deviceId,
      homeId: d.homeId,
      roomId: d.roomId,
      name: d.name,
      product: d.product,
      gangsCount: d.gangsCount,
      gangs: gangsList,
      fwVersion: d.fwVersion,
      gatewayId: d.gatewayId,
      shadow: shadow,
    );
  }

  @override
  Future<void> deleteDevice(String deviceId) async {
    await (delete(cachedDevices)..where((t) => t.deviceId.equals(deviceId))).go();
    await (delete(cachedShadows)..where((t) => t.deviceId.equals(deviceId))).go();
    await (delete(cachedSchedules)..where((t) => t.deviceId.equals(deviceId))).go();
  }

  @override
  Future<void> saveShadow(String deviceId, Shadow shadow) async {
    await into(cachedShadows).insertOnConflictUpdate(
      CachedShadowsCompanion.insert(
        deviceId: deviceId,
        desiredJson: jsonEncode(shadow.desired),
        reportedJson: jsonEncode(shadow.reported),
        ver: shadow.ver,
        online: shadow.online,
      ),
    );
  }

  @override
  Future<Shadow?> getShadow(String deviceId) async {
    final row = await (select(cachedShadows)..where((t) => t.deviceId.equals(deviceId)))
        .getSingleOrNull();
    if (row == null) return null;

    return Shadow(
      desired: jsonDecode(row.desiredJson) as Map<String, dynamic>,
      reported: jsonDecode(row.reportedJson) as Map<String, dynamic>,
      ver: row.ver,
      online: row.online,
    );
  }

  @override
  Future<void> saveSchedules(String deviceId, List<Schedule> schedules) async {
    await (delete(cachedSchedules)..where((t) => t.deviceId.equals(deviceId))).go();
    await batch((b) {
      b.insertAll(
        cachedSchedules,
        schedules.map(
          (s) => CachedSchedulesCompanion.insert(
            scheduleId: s.scheduleId,
            deviceId: s.deviceId,
            gangId: s.gangId,
            hour: s.hour,
            minute: s.minute,
            repeatDaysJson: jsonEncode(s.repeatDays),
            action: s.action.name,
            isEnabled: s.isEnabled,
            syncedToDevice: s.syncedToDevice,
          ),
        ),
      );
    });
  }

  @override
  Future<List<Schedule>> getSchedules(String deviceId) async {
    final rows =
        await (select(cachedSchedules)..where((t) => t.deviceId.equals(deviceId))).get();
    return rows
        .map(
          (r) => Schedule(
            scheduleId: r.scheduleId,
            deviceId: r.deviceId,
            gangId: r.gangId,
            hour: r.hour,
            minute: r.minute,
            repeatDays: (jsonDecode(r.repeatDaysJson) as List<dynamic>)
                .map((e) => (e as num).toInt())
                .toList(),
            action: ScheduleAction.fromString(r.action),
            isEnabled: r.isEnabled,
            syncedToDevice: r.syncedToDevice,
          ),
        )
        .toList();
  }

  @override
  Future<void> deleteSchedule(String scheduleId) async {
    await (delete(cachedSchedules)..where((t) => t.scheduleId.equals(scheduleId))).go();
  }

  @override
  Future<void> clearAll() async {
    await delete(cachedSchedules).go();
    await delete(cachedShadows).go();
    await delete(cachedDevices).go();
    await delete(cachedRooms).go();
    await delete(cachedHomes).go();
  }
}
