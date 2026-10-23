import 'package:flutter/foundation.dart';

/// Represents a device shadow state mirrored locally and in cloud (Blueprint §1, §3.5, §3.6).
@immutable
class Shadow {
  final Map<String, dynamic> desired;
  final Map<String, dynamic> reported;
  final int ver;
  final bool online;

  const Shadow({
    this.desired = const {},
    this.reported = const {},
    this.ver = 0,
    this.online = true,
  });

  Shadow copyWith({
    Map<String, dynamic>? desired,
    Map<String, dynamic>? reported,
    int? ver,
    bool? online,
  }) {
    return Shadow(
      desired: desired ?? this.desired,
      reported: reported ?? this.reported,
      ver: ver ?? this.ver,
      online: online ?? this.online,
    );
  }

  /// Helper to check if a specific gang is reported as ON
  bool isGangOn(String gangId) {
    final gangState = reported[gangId];
    if (gangState is Map<String, dynamic>) {
      return (gangState['on'] as bool?) ?? false;
    }
    if (gangState is bool) {
      return gangState;
    }
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'desired': desired,
      'reported': reported,
      'ver': ver,
      'online': online,
    };
  }

  factory Shadow.fromJson(Map<String, dynamic> json) {
    return Shadow(
      desired: (json['desired'] as Map<String, dynamic>?) ?? {},
      reported: (json['reported'] as Map<String, dynamic>?) ?? {},
      ver: (json['ver'] as num?)?.toInt() ?? 0,
      online: (json['online'] as bool?) ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Shadow &&
          runtimeType == other.runtimeType &&
          mapEquals(desired, other.desired) &&
          mapEquals(reported, other.reported) &&
          ver == other.ver &&
          online == other.online;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(desired.entries),
        Object.hashAll(reported.entries),
        ver,
        online,
      );

  @override
  String toString() => 'Shadow(ver: $ver, online: $online, reported: $reported)';
}
