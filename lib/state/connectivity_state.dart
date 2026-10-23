import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ConnectivityState {
  final bool isCloudConnected;
  final Map<String, bool> gatewayReachability; // gatewayId -> reachable
  final Set<String> bleConnectedDevices; // deviceId set

  const ConnectivityState({
    this.isCloudConnected = false,
    this.gatewayReachability = const {},
    this.bleConnectedDevices = const {},
  });

  bool isGatewayReachable(String gatewayId) => gatewayReachability[gatewayId] ?? false;

  ConnectivityState copyWith({
    bool? isCloudConnected,
    Map<String, bool>? gatewayReachability,
    Set<String>? bleConnectedDevices,
  }) {
    return ConnectivityState(
      isCloudConnected: isCloudConnected ?? this.isCloudConnected,
      gatewayReachability: gatewayReachability ?? this.gatewayReachability,
      bleConnectedDevices: bleConnectedDevices ?? this.bleConnectedDevices,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectivityState &&
          runtimeType == other.runtimeType &&
          isCloudConnected == other.isCloudConnected &&
          mapEquals(gatewayReachability, other.gatewayReachability) &&
          setEquals(bleConnectedDevices, other.bleConnectedDevices);

  @override
  int get hashCode => Object.hash(
        isCloudConnected,
        Object.hashAll(gatewayReachability.entries),
        Object.hashAll(bleConnectedDevices),
      );

  @override
  String toString() =>
      'ConnectivityState(cloud: $isCloudConnected, gwCount: ${gatewayReachability.length}, ble: ${bleConnectedDevices.length})';
}

class ConnectivityNotifier extends Notifier<ConnectivityState> {
  @override
  ConnectivityState build() {
    return const ConnectivityState();
  }

  void setCloudConnected(bool connected) {
    state = state.copyWith(isCloudConnected: connected);
  }

  void setGatewayReachable(String gatewayId, bool reachable) {
    final updated = Map<String, bool>.from(state.gatewayReachability)..[gatewayId] = reachable;
    state = state.copyWith(gatewayReachability: updated);
  }

  void setBleConnected(String deviceId, bool connected) {
    final updated = Set<String>.from(state.bleConnectedDevices);
    if (connected) {
      updated.add(deviceId);
    } else {
      updated.remove(deviceId);
    }
    state = state.copyWith(bleConnectedDevices: updated);
  }
}

final connectivityStateProvider =
    NotifierProvider<ConnectivityNotifier, ConnectivityState>(ConnectivityNotifier.new);
