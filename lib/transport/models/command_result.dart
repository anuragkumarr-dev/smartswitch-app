import 'package:flutter/foundation.dart';
import 'message_envelope.dart';

/// Result status of a command dispatched via CommandRouter (Blueprint §3.3).
enum CmdResult {
  /// Command confirmed and acknowledged by device/gateway.
  success,

  /// Neither local nor cloud path was reachable.
  unreachable,

  /// Command timed out waiting for ACK on all available paths.
  timeout,

  /// Command timestamp was older than 30 seconds and rejected.
  expired,

  /// Command was a duplicate and returned previously confirmed state.
  duplicate,

  /// Command execution failed on the device.
  failed,
}

/// Rich result returned from CommandRouter.send.
@immutable
class CommandResult {
  final CmdResult status;
  final String commandId;
  final MessageEnvelope? ack;
  final String? errorMessage;
  final bool usedCloudFallback;
  final int roundTripMs;

  const CommandResult({
    required this.status,
    required this.commandId,
    this.ack,
    this.errorMessage,
    this.usedCloudFallback = false,
    this.roundTripMs = 0,
  });

  bool get isSuccess => status == CmdResult.success;

  factory CommandResult.success({
    required String commandId,
    required MessageEnvelope ack,
    bool usedCloudFallback = false,
    int roundTripMs = 0,
  }) {
    return CommandResult(
      status: CmdResult.success,
      commandId: commandId,
      ack: ack,
      usedCloudFallback: usedCloudFallback,
      roundTripMs: roundTripMs,
    );
  }

  factory CommandResult.unreachable(String commandId) {
    return CommandResult(
      status: CmdResult.unreachable,
      commandId: commandId,
      errorMessage: 'Device unreachable via local and cloud paths',
    );
  }

  factory CommandResult.timeout(String commandId, {bool usedCloud = false}) {
    return CommandResult(
      status: CmdResult.timeout,
      commandId: commandId,
      usedCloudFallback: usedCloud,
      errorMessage: 'Command timed out waiting for device acknowledgement',
    );
  }

  factory CommandResult.expired(String commandId) {
    return CommandResult(
      status: CmdResult.expired,
      commandId: commandId,
      errorMessage: 'Command expired (>30s) and was rejected',
    );
  }

  factory CommandResult.failed(String commandId, String reason) {
    return CommandResult(
      status: CmdResult.failed,
      commandId: commandId,
      errorMessage: reason,
    );
  }

  @override
  String toString() =>
      'CommandResult($status, cmdId: $commandId, roundTrip: ${roundTripMs}ms, cloudFallback: $usedCloudFallback)';
}
