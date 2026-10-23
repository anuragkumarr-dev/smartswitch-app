import 'dart:async';
import '../domain/models/models.dart';
import 'api_client/api_client.dart';
import 'local_db/local_database.dart';

/// Repository that manages device persistence and reconciles REST snapshots
/// with live deltas using the monotonic `ver` rule (Blueprint §3.1 & §3.6).
class DeviceRepository {
  final AppLocalDatabase localDatabase;
  final ApiClient apiClient;

  final Map<String, Device> _devicesCache = {};
  final StreamController<Map<String, Device>> _devicesController =
      StreamController<Map<String, Device>>.broadcast();

  DeviceRepository({
    required this.localDatabase,
    required this.apiClient,
  });

  /// Stream of all active devices in memory, mapped by `deviceId`.
  Stream<Map<String, Device>> get devicesStream => _devicesController.stream;

  /// Returns current in-memory map of devices.
  Map<String, Device> get currentDevices => Map.unmodifiable(_devicesCache);

  /// Offline start: loads cached devices from SQLite database immediately.
  Future<List<Device>> loadFromCache(String homeId) async {
    final cached = await localDatabase.getDevices(homeId);
    for (final dev in cached) {
      _devicesCache[dev.deviceId] = dev;
    }
    _devicesController.add(Map.from(_devicesCache));
    return cached;
  }

  /// Reconciles local state with a cloud REST snapshot after reconnecting.
  /// Uses monotonic version check so locally newer writes are not overwritten.
  Future<List<Device>> reconcileWithSnapshot(String homeId) async {
    final snapshot = await apiClient.getDevicesSnapshot(homeId);
    final cachedList = await localDatabase.getDevices(homeId);
    final cachedMap = {for (final d in cachedList) d.deviceId: d};

    final reconciled = <Device>[];

    for (final snapDevice in snapshot) {
      final cached = cachedMap[snapDevice.deviceId];
      if (cached == null) {
        // Brand new device from cloud
        reconciled.add(snapDevice);
        _devicesCache[snapDevice.deviceId] = snapDevice;
      } else {
        // Monotonic version comparison: keep highest version
        if (snapDevice.shadow.ver >= cached.shadow.ver) {
          // Snapshot is newer or equal
          final updated = snapDevice.copyWith(
            gangs: _mergeGangsWithReported(snapDevice.gangs, snapDevice.shadow.reported),
          );
          reconciled.add(updated);
          _devicesCache[snapDevice.deviceId] = updated;
        } else {
          // Local cache has higher ver (unreported local write), keep local shadow
          reconciled.add(cached);
          _devicesCache[cached.deviceId] = cached;
        }
      }
    }

    // Persist reconciled state into local DB
    await localDatabase.saveDevices(reconciled);
    _devicesController.add(Map.from(_devicesCache));
    return reconciled;
  }

  /// Applies a live delta or state report using the monotonic `ver` rule (Blueprint §3.6).
  /// Returns `true` if accepted, or `false` if rejected as stale (ver <= cached.ver).
  Future<bool> applyLiveDelta({
    required String deviceId,
    required Map<String, dynamic> reported,
    required int ver,
  }) async {
    final existing = _devicesCache[deviceId] ?? await localDatabase.getDevice(deviceId);
    if (existing == null) return false;

    // Monotonic ver rule: ignore any report with ver <= current ver
    if (ver <= existing.shadow.ver) {
      return false; // Stale delta dropped
    }

    // Merge reported state
    final mergedReported = Map<String, dynamic>.from(existing.shadow.reported)..addAll(reported);
    final updatedShadow = existing.shadow.copyWith(
      reported: mergedReported,
      ver: ver,
      online: true,
    );

    final updatedGangs = _mergeGangsWithReported(existing.gangs, mergedReported);
    final updatedDevice = existing.copyWith(
      shadow: updatedShadow,
      gangs: updatedGangs,
    );

    _devicesCache[deviceId] = updatedDevice;
    await localDatabase.saveShadow(deviceId, updatedShadow);
    await localDatabase.saveDevices([updatedDevice]);

    _devicesController.add(Map.from(_devicesCache));
    return true;
  }

  /// Updates device shadow directly (e.g. from confirmed command ACK).
  Future<void> updateDeviceShadow(String deviceId, Shadow shadow) async {
    final existing = _devicesCache[deviceId] ?? await localDatabase.getDevice(deviceId);
    if (existing == null) return;

    final updatedGangs = _mergeGangsWithReported(existing.gangs, shadow.reported);
    final updatedDevice = existing.copyWith(
      shadow: shadow,
      gangs: updatedGangs,
    );

    _devicesCache[deviceId] = updatedDevice;
    await localDatabase.saveShadow(deviceId, shadow);
    await localDatabase.saveDevices([updatedDevice]);

    _devicesController.add(Map.from(_devicesCache));
  }

  /// Helper to synchronize Gang isOn properties with shadow reported values.
  List<Gang> _mergeGangsWithReported(List<Gang> gangs, Map<String, dynamic> reported) {
    return gangs.map((g) {
      final gangVal = reported[g.gangId];
      bool isOn = g.isOn;
      if (gangVal is Map<String, dynamic>) {
        isOn = (gangVal['on'] as bool?) ?? isOn;
      } else if (gangVal is bool) {
        isOn = gangVal;
      }
      return g.copyWith(isOn: isOn);
    }).toList();
  }

  void dispose() {
    _devicesController.close();
  }
}
