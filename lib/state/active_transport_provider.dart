import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../transport/blynk_bridge_controller.dart';
import '../transport/blynk_transport.dart';
import '../transport/cloud_transport.dart';
import '../transport/command_router.dart';
import '../transport/local_transport.dart';
import '../transport/mdns_service.dart';
import '../transport/models/message_envelope.dart';
import 'app_mode_state.dart';
import 'devices_state.dart';

/// In-memory mock cloud transport for Demo mode.
class MockCloudTransport implements CloudTransport {
  bool _isConnected = true;
  @override
  bool get isConnected => _isConnected;

  @override
  Stream<MessageEnvelope> get incomingMessages => const Stream.empty();

  @override
  Future<bool> connect({
    required String homeId,
    required String brokerUrl,
    int port = 8883,
    String? clientIdentifier,
  }) async {
    _isConnected = true;
    return true;
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
  }

  @override
  Future<MessageEnvelope?> send(
    String homeId,
    String deviceId,
    MessageEnvelope envelope, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    return MessageEnvelope.ack(
      deviceId: deviceId,
      commandId: envelope.commandId,
      reported: envelope.desired ?? {},
      ver: (envelope.ver ?? 1) + 1,
      ts: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  Future<void> subscribeToHome(String homeId) async {}
}

/// Provider for the active [CloudTransport]:
/// Switches between [BlynkCloudTransport] when mode is Blynk, and [MockCloudTransport] when mode is Demo.
final activeCloudTransportProvider = Provider<CloudTransport>((ref) {
  final mode = ref.watch(appModeProvider);
  if (mode.isBlynk) {
    return ref.watch(blynkTransportProvider);
  }
  return MockCloudTransport();
});

/// Provider for the active [CommandRouter]:
/// Dispatches commands using the appropriate active cloud transport.
final commandRouterProvider = Provider<CommandRouter>((ref) {
  final cloud = ref.watch(activeCloudTransportProvider);
  final local = LocalTransport(
    mdnsService: FakeMdnsService(),
    homeKey: List.filled(32, 0),
  );

  final router = CommandRouter(
    local: local,
    cloud: cloud,
    onPending: (deviceId, desired, commandId) {
      final gangId = desired.keys.firstOrNull ?? 'gang1';
      final dynamic val = desired[gangId];
      final bool isOn = val is Map<String, dynamic> ? (val['on'] == true) : (val == true);
      ref.read(devicesStateProvider.notifier).markPending(
            deviceId: deviceId,
            gangId: gangId,
            desired: isOn,
            commandId: commandId,
          );
    },
    onConfirmed: (deviceId, commandId, ack) {
      ref.read(devicesStateProvider.notifier).confirm(
            deviceId: deviceId,
            commandId: commandId,
            ver: ack.ver ?? 1,
            reported: ack.reported ?? {},
          );
    },
    onRollback: (deviceId, commandId) {
      ref.read(devicesStateProvider.notifier).rollback(
            deviceId: deviceId,
            commandId: commandId,
          );
    },
  );

  return router;
});
