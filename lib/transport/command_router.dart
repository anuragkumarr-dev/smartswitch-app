import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import 'cloud_transport.dart';
import 'local_transport.dart';
import 'models/command_result.dart';
import 'models/message_envelope.dart';

/// Callbacks for optimistic UI state management (Blueprint §3.2).
typedef OnPendingCallback = void Function(
    String deviceId, Map<String, dynamic> desired, String commandId);
typedef OnConfirmedCallback = void Function(
    String deviceId, String commandId, MessageEnvelope ack);
typedef OnRollbackCallback = void Function(
    String deviceId, String commandId);

/// Dual-path Command Router implementing Blueprint §3.3:
/// - Optimistic pending state in the same frame
/// - Local-first via WebSocket with 800 ms timeout
/// - Cloud fallback via MQTT with 4 s timeout
/// - Idempotent commandId generation and de-duplication
/// - 30-second command expiry enforcement
/// - Reachability probing instead of SSID checks
/// - Immediate re-probing on connectivity changes
class CommandRouter {
  final LocalTransport local;
  final CloudTransport cloud;
  final Duration localTimeout;
  final Duration cloudTimeout;
  final Duration maxCommandAge;

  OnPendingCallback? onPending;
  OnConfirmedCallback? onConfirmed;
  OnRollbackCallback? onRollback;

  static final Random _random = Random.secure();

  CommandRouter({
    required this.local,
    required this.cloud,
    this.localTimeout = const Duration(milliseconds: 800),
    this.cloudTimeout = const Duration(seconds: 4),
    this.maxCommandAge = const Duration(seconds: 30),
    this.onPending,
    this.onConfirmed,
    this.onRollback,
  });

  /// Generates a globally unique idempotency key for a command.
  static String newCommandId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final rand = _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return 'c_${timestamp}_$rand';
  }

  /// Dispatches an absolute state command with dual-path routing and optimistic UI updates.
  Future<CommandResult> sendCommand({
    required String homeId,
    required String gatewayId,
    required String deviceId,
    required Map<String, dynamic> desired,
    String? commandId,
    int? timestamp,
  }) async {
    final cmdId = commandId ?? newCommandId();
    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;

    final envelope = MessageEnvelope.cmd(
      deviceId: deviceId,
      commandId: cmdId,
      desired: desired,
      ts: ts,
    );

    // Rule: Commands expire after ~30s. Never replay stale switching commands (Blueprint §3.3)
    if (envelope.isExpired(maxAge: maxCommandAge)) {
      return CommandResult.expired(cmdId);
    }

    final stopwatch = Stopwatch()..start();

    // 1. Optimistic UI update in the same frame (Blueprint §3.2)
    onPending?.call(deviceId, desired, cmdId);

    // 2. Path 1: Local-first if Root is reachable (800 ms timeout)
    if (local.isReachable(gatewayId)) {
      try {
        final ack = await local
            .send(gatewayId, envelope, timeout: localTimeout)
            .timeout(localTimeout, onTimeout: () => null);

        if (ack != null) {
          stopwatch.stop();
          onConfirmed?.call(deviceId, cmdId, ack);
          return CommandResult.success(
            commandId: cmdId,
            ack: ack,
            usedCloudFallback: false,
            roundTripMs: stopwatch.elapsedMilliseconds,
          );
        }
      } catch (e) {
        debugPrint('Local path exception for $cmdId: $e');
      }
    }

    // 3. Path 2: Cloud fallback if local timed out or was slow / unreachable (4 s timeout)
    if (cloud.isConnected) {
      try {
        final ack = await cloud
            .send(homeId, deviceId, envelope, timeout: cloudTimeout)
            .timeout(cloudTimeout, onTimeout: () => null);

        if (ack != null) {
          stopwatch.stop();
          onConfirmed?.call(deviceId, cmdId, ack);
          return CommandResult.success(
            commandId: cmdId,
            ack: ack,
            usedCloudFallback: true,
            roundTripMs: stopwatch.elapsedMilliseconds,
          );
        }
      } catch (e) {
        debugPrint('Cloud path exception for $cmdId: $e');
      }
    }

    // 4. Nothing answered: Rollback optimistic state
    stopwatch.stop();
    onRollback?.call(deviceId, cmdId);

    if (!local.isReachable(gatewayId) && !cloud.isConnected) {
      return CommandResult.unreachable(cmdId);
    }

    return CommandResult.timeout(
      cmdId,
      usedCloud: cloud.isConnected,
    );
  }

  /// Notifies the router of network/connectivity changes to trigger immediate re-probing.
  Future<void> onNetworkChanged() async {
    await local.reprobe();
  }
}
