import '../../domain/models/models.dart';

/// Abstract contract for local offline caching of homes, devices, shadows, and schedules (Blueprint §3.1 & §3.6).
abstract interface class AppLocalDatabase {
  Future<void> init();

  // Homes
  Future<void> saveHomes(List<Home> homes);
  Future<List<Home>> getHomes();
  Future<Home?> getHome(String homeId);

  // Rooms
  Future<void> saveRooms(List<Room> rooms);
  Future<List<Room>> getRooms(String homeId);

  // Devices
  Future<void> saveDevices(List<Device> devices);
  Future<List<Device>> getDevices(String homeId);
  Future<Device?> getDevice(String deviceId);
  Future<void> deleteDevice(String deviceId);

  // Shadows
  Future<void> saveShadow(String deviceId, Shadow shadow);
  Future<Shadow?> getShadow(String deviceId);

  // Schedules
  Future<void> saveSchedules(String deviceId, List<Schedule> schedules);
  Future<List<Schedule>> getSchedules(String deviceId);
  Future<void> deleteSchedule(String scheduleId);

  // Clear
  Future<void> clearAll();
  Future<void> close();
}
