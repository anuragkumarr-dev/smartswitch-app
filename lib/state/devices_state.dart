import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/device_repository.dart';
import '../domain/models/models.dart';
import '../transport/command_router.dart';
import '../transport/models/command_result.dart';

/// Presentation state for a single device, combining confirmed shadow state
/// with optimistic in-flight pending updates (Blueprint §3.2).
@immutable
class DeviceUiState {
  final Device device;
  final Shadow shadow;
  final String? pendingCommandId;
  final Map<String, bool> pendingGangStates; // gangId -> desired isOn
  final String? errorMessage;

  const DeviceUiState({
    required this.device,
    required this.shadow,
    this.pendingCommandId,
    this.pendingGangStates = const {},
    this.errorMessage,
  });

  /// Whether any gang command is currently pending in-flight.
  bool get isPending => pendingCommandId != null && pendingGangStates.isNotEmpty;

  /// Whether a specific gang has an optimistic pending toggle.
  bool isGangPending(String gangId) => pendingGangStates.containsKey(gangId);

  /// Returns the effective state for a gang:
  /// - Optimistic pending state if a command is in-flight
  /// - Confirmed reported shadow state otherwise
  bool effectiveGangIsOn(String gangId) {
    if (pendingGangStates.containsKey(gangId)) {
      return pendingGangStates[gangId]!;
    }
    final gang = device.gangs.cast<Gang?>().firstWhere(
          (g) => g?.gangId == gangId,
          orElse: () => null,
        );
    if (gang != null) return gang.isOn;
    return shadow.isGangOn(gangId);
  }

  DeviceUiState copyWith({
    Device? device,
    Shadow? shadow,
    String? pendingCommandId,
    Map<String, bool>? pendingGangStates,
    String? errorMessage,
    bool clearPending = false,
  }) {
    return DeviceUiState(
      device: device ?? this.device,
      shadow: shadow ?? this.shadow,
      pendingCommandId: clearPending ? null : (pendingCommandId ?? this.pendingCommandId),
      pendingGangStates: clearPending ? const {} : (pendingGangStates ?? this.pendingGangStates),
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceUiState &&
          runtimeType == other.runtimeType &&
          device == other.device &&
          shadow == other.shadow &&
          pendingCommandId == other.pendingCommandId &&
          mapEquals(pendingGangStates, other.pendingGangStates) &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
        device,
        shadow,
        pendingCommandId,
        Object.hashAll(pendingGangStates.entries),
        errorMessage,
      );

  @override
  String toString() =>
      'DeviceUiState(${device.deviceId}, pending: $isPending, ver: ${shadow.ver})';
}

/// Map of deviceId -> DeviceUiState.
typedef DevicesState = Map<String, DeviceUiState>;

/// Riverpod notifier managing device states, optimistic updates, ACKs,
/// rollback, and monotonic versioning (Blueprint §3.2, §3.3, §3.6).
class DevicesNotifier extends Notifier<DevicesState> {
  DeviceRepository? _repository;
  StreamSubscription? _repoSubscription;

  void setRepository(DeviceRepository repo) {
    _repository = repo;
    _repoSubscription?.cancel();
    _repoSubscription = repo.devicesStream.listen((devicesMap) {
      _onRepositoryDevicesUpdated(devicesMap);
    });
  }

  @override
  DevicesState build() {
    ref.onDispose(() {
      _repoSubscription?.cancel();
    });
    return const {};
  }

  /// Initializes devices from a list (e.g. from cache or snapshot).
  void setDevices(List<Device> devices) {
    final next = <String, DeviceUiState>{};
    for (final dev in devices) {
      final existing = state[dev.deviceId];
      next[dev.deviceId] = DeviceUiState(
        device: dev,
        shadow: dev.shadow,
        pendingCommandId: existing?.pendingCommandId,
        pendingGangStates: existing?.pendingGangStates ?? const {},
      );
    }
    state = next;
  }

  /// Step 1 (Blueprint §3.2): Mark pending in the exact same frame upon user tap.
  /// Immediate synchronous state change without awaiting network.
  void markPending({
    required String deviceId,
    required String gangId,
    required bool desired,
    required String commandId,
  }) {
    final current = state[deviceId];
    if (current == null) return;

    final updatedPendingGangs = Map<String, bool>.from(current.pendingGangStates)
      ..[gangId] = desired;

    final updatedItem = current.copyWith(
      pendingCommandId: commandId,
      pendingGangStates: updatedPendingGangs,
      errorMessage: null,
    );

    state = Map<String, DeviceUiState>.from(state)..[deviceId] = updatedItem;
  }

  /// Step 3 (Blueprint §3.2): Confirm state upon receiving an ACK or state report
  /// with matching commandId. Clears pending state and commits reported state.
  Future<void> confirm({
    required String deviceId,
    required String commandId,
    required int ver,
    required Map<String, dynamic> reported,
  }) async {
    final current = state[deviceId];
    if (current == null) return;

    // Check monotonic version rule: don't accept older versions
    if (ver < current.shadow.ver) return;

    // Merge reported state
    final mergedReported = Map<String, dynamic>.from(current.shadow.reported)..addAll(reported);
    final updatedShadow = current.shadow.copyWith(
      reported: mergedReported,
      ver: ver,
      online: true,
    );

    // Update gang models
    final updatedGangs = current.device.gangs.map((g) {
      final gangVal = mergedReported[g.gangId];
      bool isOn = g.isOn;
      if (gangVal is Map<String, dynamic>) {
        isOn = (gangVal['on'] as bool?) ?? isOn;
      } else if (gangVal is bool) {
        isOn = gangVal;
      }
      return g.copyWith(isOn: isOn);
    }).toList();

    final updatedDevice = current.device.copyWith(
      shadow: updatedShadow,
      gangs: updatedGangs,
    );

    final updatedItem = current.copyWith(
      device: updatedDevice,
      shadow: updatedShadow,
      clearPending: true,
      errorMessage: null,
    );

    state = Map<String, DeviceUiState>.from(state)..[deviceId] = updatedItem;
    await _repository?.updateDeviceShadow(deviceId, updatedShadow);
  }

  /// Step 4 (Blueprint §3.2): Rollback optimistic state to last confirmed state
  /// if both local and cloud transports fail or time out.
  void rollback({
    required String deviceId,
    required String commandId,
    String? errorMessage,
  }) {
    final current = state[deviceId];
    if (current == null) return;

    if (current.pendingCommandId == commandId) {
      final updatedItem = current.copyWith(
        clearPending: true,
        errorMessage: errorMessage ?? 'Device unreachable',
      );
      state = Map<String, DeviceUiState>.from(state)..[deviceId] = updatedItem;
    }
  }

  /// Applies a live delta or cloud push using monotonic `ver` rule (Blueprint §3.6).
  void applyLiveDelta({
    required String deviceId,
    required Map<String, dynamic> reported,
    required int ver,
  }) {
    final current = state[deviceId];
    if (current == null) return;

    if (ver <= current.shadow.ver) {
      // Ignore stale report
      return;
    }

    final mergedReported = Map<String, dynamic>.from(current.shadow.reported)..addAll(reported);
    final updatedShadow = current.shadow.copyWith(
      reported: mergedReported,
      ver: ver,
      online: true,
    );

    final updatedGangs = current.device.gangs.map((g) {
      final gangVal = mergedReported[g.gangId];
      bool isOn = g.isOn;
      if (gangVal is Map<String, dynamic>) {
        isOn = (gangVal['on'] as bool?) ?? isOn;
      } else if (gangVal is bool) {
        isOn = gangVal;
      }
      return g.copyWith(isOn: isOn);
    }).toList();

    final updatedDevice = current.device.copyWith(
      shadow: updatedShadow,
      gangs: updatedGangs,
    );

    final updatedItem = current.copyWith(
      device: updatedDevice,
      shadow: updatedShadow,
    );

    state = Map<String, DeviceUiState>.from(state)..[deviceId] = updatedItem;
    _repository?.updateDeviceShadow(deviceId, updatedShadow);
  }

  /// High-level action: Toggles a gang with optimistic feedback, dual-path routing,
  /// and automatic rollback on failure (Blueprint §3.2 & §3.3).
  Future<CmdResult> toggleGang({
    required String deviceId,
    required String gangId,
    required CommandRouter router,
  }) async {
    final current = state[deviceId];
    if (current == null) return CmdResult.unreachable;

    final currentIsOn = current.effectiveGangIsOn(gangId);
    final desiredIsOn = !currentIsOn;
    final commandId = CommandRouter.newCommandId();

    // 1. Optimistic pending in the SAME frame
    markPending(
      deviceId: deviceId,
      gangId: gangId,
      desired: desiredIsOn,
      commandId: commandId,
    );

    // 2. Dispatch via CommandRouter (local-first with cloud fallback)
    final result = await router.sendCommand(
      homeId: current.device.homeId,
      gatewayId: current.device.gatewayId,
      deviceId: deviceId,
      desired: {
        gangId: {'on': desiredIsOn},
      },
      commandId: commandId,
    );

    // 3. Confirm or Rollback
    if (result.isSuccess && result.ack != null) {
      final ack = result.ack!;
      final reported = ack.reported ??
          {
            gangId: {'on': desiredIsOn},
          };
      await confirm(
        deviceId: deviceId,
        commandId: commandId,
        ver: ack.ver ?? (current.shadow.ver + 1),
        reported: reported,
      );
      return result.status;
    } else {
      rollback(
        deviceId: deviceId,
        commandId: commandId,
        errorMessage: result.errorMessage ?? 'Command failed',
      );
      return result.status;
    }
  }

  void _onRepositoryDevicesUpdated(Map<String, Device> devicesMap) {
    final next = <String, DeviceUiState>{};
    for (final dev in devicesMap.values) {
      final existing = state[dev.deviceId];
      next[dev.deviceId] = DeviceUiState(
        device: dev,
        shadow: dev.shadow,
        pendingCommandId: existing?.pendingCommandId,
        pendingGangStates: existing?.pendingGangStates ?? const {},
      );
    }
    state = next;
  }
}

final devicesStateProvider = NotifierProvider<DevicesNotifier, DevicesState>(DevicesNotifier.new);
