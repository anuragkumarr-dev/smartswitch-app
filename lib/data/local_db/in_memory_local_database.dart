import 'dart:async';
import '../../domain/models/models.dart';
import 'local_database.dart';

/// In-memory implementation of [AppLocalDatabase] for testing, preview, and mock-first runs.
class InMemoryLocalDatabase implements AppLocalDatabase {
  final Map<String, Home> _homes = {};
  final Map<String, List<Room>> _roomsByHome = {};
  final Map<String, Device> _devices = {};
  final Map<String, Shadow> _shadows = {};
  final Map<String, List<Schedule>> _schedulesByDevice = {};

  InMemoryLocalDatabase({
    List<Home>? initialHomes,
    List<Device>? initialDevices,
  }) {
    if (initialHomes != null) {
      for (final h in initialHomes) {
        _homes[h.homeId] = h;
      }
    }
    if (initialDevices != null) {
      for (final d in initialDevices) {
        _devices[d.deviceId] = d;
        _shadows[d.deviceId] = d.shadow;
      }
    }
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> saveHomes(List<Home> homes) async {
    for (final h in homes) {
      _homes[h.homeId] = h;
    }
  }

  @override
  Future<List<Home>> getHomes() async {
    return _homes.values.toList();
  }

  @override
  Future<Home?> getHome(String homeId) async {
    return _homes[homeId];
  }

  @override
  Future<void> saveRooms(List<Room> rooms) async {
    for (final r in rooms) {
      final list = _roomsByHome.putIfAbsent(r.homeId, () => []);
      list.removeWhere((existing) => existing.roomId == r.roomId);
      list.add(r);
    }
  }

  @override
  Future<List<Room>> getRooms(String homeId) async {
    return _roomsByHome[homeId] ?? [];
  }

  @override
  Future<void> saveDevices(List<Device> devices) async {
    for (final d in devices) {
      _devices[d.deviceId] = d;
      _shadows[d.deviceId] = d.shadow;
    }
  }

  @override
  Future<List<Device>> getDevices(String homeId) async {
    return _devices.values.where((d) => d.homeId == homeId).map((d) {
      final shadow = _shadows[d.deviceId] ?? d.shadow;
      return d.copyWith(shadow: shadow);
    }).toList();
  }

  @override
  Future<Device?> getDevice(String deviceId) async {
    final d = _devices[deviceId];
    if (d == null) return null;
    final shadow = _shadows[deviceId] ?? d.shadow;
    return d.copyWith(shadow: shadow);
  }

  @override
  Future<void> deleteDevice(String deviceId) async {
    _devices.remove(deviceId);
    _shadows.remove(deviceId);
    _schedulesByDevice.remove(deviceId);
  }

  @override
  Future<void> saveShadow(String deviceId, Shadow shadow) async {
    _shadows[deviceId] = shadow;
    if (_devices.containsKey(deviceId)) {
      _devices[deviceId] = _devices[deviceId]!.copyWith(shadow: shadow);
    }
  }

  @override
  Future<Shadow?> getShadow(String deviceId) async {
    return _shadows[deviceId];
  }

  @override
  Future<void> saveSchedules(String deviceId, List<Schedule> schedules) async {
    _schedulesByDevice[deviceId] = List.from(schedules);
  }

  @override
  Future<List<Schedule>> getSchedules(String deviceId) async {
    return _schedulesByDevice[deviceId] ?? [];
  }

  @override
  Future<void> deleteSchedule(String scheduleId) async {
    for (final list in _schedulesByDevice.values) {
      list.removeWhere((s) => s.scheduleId == scheduleId);
    }
  }

  @override
  Future<void> clearAll() async {
    _homes.clear();
    _roomsByHome.clear();
    _devices.clear();
    _shadows.clear();
    _schedulesByDevice.clear();
  }

  @override
  Future<void> close() async {}
}
