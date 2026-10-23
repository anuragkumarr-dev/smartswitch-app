import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Standard message envelope specification from docs/protocol.md and Blueprint §3.3.
@immutable
class MessageEnvelope {
  /// Protocol version. Always 1 for current release.
  final int v;

  /// Message type: cmd, ack, state, heartbeat, handshake_init, handshake_resp, handshake_confirm, error.
  final String type;

  /// Target or reporting switch identifier.
  final String deviceId;

  /// Unique idempotency key.
  final String commandId;

  /// Desired state payload sent to device (commands).
  final Map<String, dynamic>? desired;

  /// Reported state payload published by device.
  final Map<String, dynamic>? reported;

  /// Monotonically increasing state version counter.
  final int? ver;

  /// Unix timestamp in milliseconds when the message was originated.
  final int ts;

  const MessageEnvelope({
    this.v = 1,
    required this.type,
    required this.deviceId,
    required this.commandId,
    this.desired,
    this.reported,
    this.ver,
    required this.ts,
  });

  /// Factory for a command message.
  factory MessageEnvelope.cmd({
    required String deviceId,
    required String commandId,
    required Map<String, dynamic> desired,
    int? ts,
  }) {
    return MessageEnvelope(
      type: 'cmd',
      deviceId: deviceId,
      commandId: commandId,
      desired: desired,
      ts: ts ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Factory for an acknowledgement message.
  factory MessageEnvelope.ack({
    required String deviceId,
    required String commandId,
    Map<String, dynamic>? reported,
    int? ver,
    int? ts,
  }) {
    return MessageEnvelope(
      type: 'ack',
      deviceId: deviceId,
      commandId: commandId,
      reported: reported,
      ver: ver,
      ts: ts ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Factory for a state report message.
  factory MessageEnvelope.state({
    required String deviceId,
    required String commandId,
    required Map<String, dynamic> reported,
    required int ver,
    int? ts,
  }) {
    return MessageEnvelope(
      type: 'state',
      deviceId: deviceId,
      commandId: commandId,
      reported: reported,
      ver: ver,
      ts: ts ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Factory for a 5-second heartbeat message.
  factory MessageEnvelope.heartbeat({
    required String gatewayId,
    int? ts,
  }) {
    final now = ts ?? DateTime.now().millisecondsSinceEpoch;
    return MessageEnvelope(
      type: 'heartbeat',
      deviceId: gatewayId,
      commandId: 'hb_$now',
      ts: now,
    );
  }

  /// Factory for handshake init message.
  factory MessageEnvelope.handshakeInit({
    required String gatewayId,
    required String clientNonceHex,
    int? ts,
  }) {
    final now = ts ?? DateTime.now().millisecondsSinceEpoch;
    return MessageEnvelope(
      type: 'handshake_init',
      deviceId: gatewayId,
      commandId: 'hs_init_$now',
      desired: {'clientNonce': clientNonceHex},
      ts: now,
    );
  }

  /// Factory for handshake response message.
  factory MessageEnvelope.handshakeResp({
    required String gatewayId,
    required String commandId,
    required String serverNonceHex,
    int? ts,
  }) {
    return MessageEnvelope(
      type: 'handshake_resp',
      deviceId: gatewayId,
      commandId: commandId,
      reported: {'serverNonce': serverNonceHex},
      ts: ts ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Factory for handshake confirm message.
  factory MessageEnvelope.handshakeConfirm({
    required String gatewayId,
    required String commandId,
    int? ts,
  }) {
    return MessageEnvelope(
      type: 'handshake_confirm',
      deviceId: gatewayId,
      commandId: commandId,
      ts: ts ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Checks whether this command message has exceeded the allowed 30-second TTL.
  bool isExpired({
    Duration maxAge = const Duration(seconds: 30),
    int? currentTimestamp,
  }) {
    final now = currentTimestamp ?? DateTime.now().millisecondsSinceEpoch;
    final ageMs = now - ts;
    return ageMs > maxAge.inMilliseconds || ageMs < -5000; // allow 5s clock drift
  }

  Map<String, dynamic> toJson() {
    return {
      'v': v,
      'type': type,
      'deviceId': deviceId,
      'commandId': commandId,
      if (desired != null) 'desired': desired,
      if (reported != null) 'reported': reported,
      if (ver != null) 'ver': ver,
      'ts': ts,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory MessageEnvelope.fromJson(Map<String, dynamic> json) {
    return MessageEnvelope(
      v: json['v'] as int? ?? 1,
      type: json['type'] as String,
      deviceId: json['deviceId'] as String,
      commandId: json['commandId'] as String,
      desired: (json['desired'] as Map?)?.cast<String, dynamic>(),
      reported: (json['reported'] as Map?)?.cast<String, dynamic>(),
      ver: json['ver'] as int?,
      ts: json['ts'] as int,
    );
  }

  factory MessageEnvelope.fromJsonString(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return MessageEnvelope.fromJson(map);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageEnvelope &&
          runtimeType == other.runtimeType &&
          v == other.v &&
          type == other.type &&
          deviceId == other.deviceId &&
          commandId == other.commandId &&
          ver == other.ver &&
          ts == other.ts;

  @override
  int get hashCode => Object.hash(v, type, deviceId, commandId, ver, ts);

  @override
  String toString() =>
      'MessageEnvelope(type: $type, dev: $deviceId, cmdId: $commandId, ver: $ver, ts: $ts)';
}
