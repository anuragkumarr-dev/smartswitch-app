import '../../domain/models/models.dart';

/// Abstract REST API client for cloud snapshot and sync operations (Blueprint §3.1 & §3.6).
abstract interface class ApiClient {
  Future<List<Home>> getHomes();
  Future<List<Device>> getDevicesSnapshot(String homeId);
  Future<List<Schedule>> getSchedules(String deviceId);
  Future<bool> updateSchedule(String deviceId, Schedule schedule);
}

/// Mock implementation of [ApiClient] for testing and offline development.
class MockApiClient implements ApiClient {
  final Map<String, List<Device>> _devicesByHome = {};
  final List<Home> _homes = [];
  final Map<String, List<Schedule>> _schedulesByDevice = {};
  Duration simulatedDelay;
  bool shouldFail = false;

  MockApiClient({
    List<Home>? initialHomes,
    Map<String, List<Device>>? initialDevices,
    this.simulatedDelay = const Duration(milliseconds: 10),
  }) {
    if (initialHomes != null) _homes.addAll(initialHomes);
    if (initialDevices != null) _devicesByHome.addAll(initialDevices);
  }

  void setDevicesSnapshot(String homeId, List<Device> devices) {
    _devicesByHome[homeId] = List.from(devices);
  }

  void addOrUpdateDevice(String homeId, Device device) {
    final list = _devicesByHome.putIfAbsent(homeId, () => []);
    list.removeWhere((d) => d.deviceId == device.deviceId);
    list.add(device);
  }

  @override
  Future<List<Home>> getHomes() async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);
    if (shouldFail) throw Exception('REST API network failure');
    return List.from(_homes);
  }

  @override
  Future<List<Device>> getDevicesSnapshot(String homeId) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);
    if (shouldFail) throw Exception('REST API network failure');
    return List.from(_devicesByHome[homeId] ?? []);
  }

  @override
  Future<List<Schedule>> getSchedules(String deviceId) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);
    if (shouldFail) throw Exception('REST API network failure');
    return List.from(_schedulesByDevice[deviceId] ?? []);
  }

  @override
  Future<bool> updateSchedule(String deviceId, Schedule schedule) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);
    if (shouldFail) return false;
    final list = _schedulesByDevice.putIfAbsent(deviceId, () => []);
    list.removeWhere((s) => s.scheduleId == schedule.scheduleId);
    list.add(schedule);
    return true;
  }
}
