import 'package:flutter/foundation.dart';

/// Action performed by a timer or schedule (Blueprint §3.7 & §4.3).
enum ScheduleAction {
  turnOn,
  turnOff;

  String get displayName => this == ScheduleAction.turnOn ? 'Turn ON' : 'Turn OFF';

  static ScheduleAction fromString(String val) {
    return val.toLowerCase() == 'turnon' || val.toLowerCase() == 'on'
        ? ScheduleAction.turnOn
        : ScheduleAction.turnOff;
  }
}

/// Represents a switch timer schedule stored and executed on the device (Blueprint §3.7).
@immutable
class Schedule {
  final String scheduleId;
  final String deviceId;
  final String gangId;
  final int hour; // 0..23
  final int minute; // 0..59
  final List<int> repeatDays; // 1=Mon, 2=Tue, ..., 7=Sun. Empty = execute once
  final ScheduleAction action;
  final bool isEnabled;
  final bool syncedToDevice;

  const Schedule({
    required this.scheduleId,
    required this.deviceId,
    required this.gangId,
    required this.hour,
    required this.minute,
    this.repeatDays = const [],
    this.action = ScheduleAction.turnOn,
    this.isEnabled = true,
    this.syncedToDevice = false,
  });

  Schedule copyWith({
    String? scheduleId,
    String? deviceId,
    String? gangId,
    int? hour,
    int? minute,
    List<int>? repeatDays,
    ScheduleAction? action,
    bool? isEnabled,
    bool? syncedToDevice,
  }) {
    return Schedule(
      scheduleId: scheduleId ?? this.scheduleId,
      deviceId: deviceId ?? this.deviceId,
      gangId: gangId ?? this.gangId,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeatDays: repeatDays ?? this.repeatDays,
      action: action ?? this.action,
      isEnabled: isEnabled ?? this.isEnabled,
      syncedToDevice: syncedToDevice ?? this.syncedToDevice,
    );
  }

  String get formattedTime {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, dynamic> toJson() {
    return {
      'scheduleId': scheduleId,
      'deviceId': deviceId,
      'gangId': gangId,
      'hour': hour,
      'minute': minute,
      'repeatDays': repeatDays,
      'action': action.name,
      'isEnabled': isEnabled,
      'syncedToDevice': syncedToDevice,
    };
  }

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      scheduleId: json['scheduleId'] as String,
      deviceId: json['deviceId'] as String,
      gangId: json['gangId'] as String,
      hour: (json['hour'] as num).toInt(),
      minute: (json['minute'] as num).toInt(),
      repeatDays: (json['repeatDays'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      action: ScheduleAction.fromString(json['action'] as String? ?? 'on'),
      isEnabled: (json['isEnabled'] as bool?) ?? true,
      syncedToDevice: (json['syncedToDevice'] as bool?) ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Schedule &&
          runtimeType == other.runtimeType &&
          scheduleId == other.scheduleId &&
          deviceId == other.deviceId &&
          gangId == other.gangId &&
          hour == other.hour &&
          minute == other.minute &&
          listEquals(repeatDays, other.repeatDays) &&
          action == other.action &&
          isEnabled == other.isEnabled &&
          syncedToDevice == other.syncedToDevice;

  @override
  int get hashCode => Object.hash(
        scheduleId,
        deviceId,
        gangId,
        hour,
        minute,
        Object.hashAll(repeatDays),
        action,
        isEnabled,
        syncedToDevice,
      );

  @override
  String toString() =>
      'Schedule($scheduleId at $formattedTime, action: ${action.name}, synced: $syncedToDevice)';
}
