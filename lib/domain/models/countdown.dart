import 'package:flutter/foundation.dart';
import 'schedule.dart';

/// Countdown timer state executed on the device (Blueprint §4.3).
@immutable
class Countdown {
  final String deviceId;
  final String gangId;
  final int durationSeconds;
  final int remainingSeconds;
  final ScheduleAction action;
  final bool isRunning;

  const Countdown({
    required this.deviceId,
    required this.gangId,
    required this.durationSeconds,
    required this.remainingSeconds,
    this.action = ScheduleAction.turnOff,
    this.isRunning = false,
  });

  Countdown copyWith({
    String? deviceId,
    String? gangId,
    int? durationSeconds,
    int? remainingSeconds,
    ScheduleAction? action,
    bool? isRunning,
  }) {
    return Countdown(
      deviceId: deviceId ?? this.deviceId,
      gangId: gangId ?? this.gangId,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      action: action ?? this.action,
      isRunning: isRunning ?? this.isRunning,
    );
  }

  String get formattedRemaining {
    final hours = remainingSeconds ~/ 3600;
    final minutes = (remainingSeconds % 3600) ~/ 60;
    final seconds = remainingSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    } else {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'gangId': gangId,
      'durationSeconds': durationSeconds,
      'remainingSeconds': remainingSeconds,
      'action': action.name,
      'isRunning': isRunning,
    };
  }

  factory Countdown.fromJson(Map<String, dynamic> json) {
    return Countdown(
      deviceId: json['deviceId'] as String,
      gangId: json['gangId'] as String,
      durationSeconds: (json['durationSeconds'] as num).toInt(),
      remainingSeconds: (json['remainingSeconds'] as num).toInt(),
      action: ScheduleAction.fromString(json['action'] as String? ?? 'turnOff'),
      isRunning: (json['isRunning'] as bool?) ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Countdown &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          gangId == other.gangId &&
          durationSeconds == other.durationSeconds &&
          remainingSeconds == other.remainingSeconds &&
          action == other.action &&
          isRunning == other.isRunning;

  @override
  int get hashCode => Object.hash(
        deviceId,
        gangId,
        durationSeconds,
        remainingSeconds,
        action,
        isRunning,
      );

  @override
  String toString() =>
      'Countdown($deviceId.$gangId: $formattedRemaining, running: $isRunning)';
}
