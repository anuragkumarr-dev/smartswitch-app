import 'package:flutter/foundation.dart';

/// Represents a SmartSwitch home location (Blueprint §1 & §3.1).
@immutable
class Home {
  final String homeId;
  final String name;
  final String timezone;
  final List<int> homeKey;
  final String meshId;
  final String meshApPassword;

  const Home({
    required this.homeId,
    required this.name,
    this.timezone = 'Asia/Kolkata',
    required this.homeKey,
    required this.meshId,
    required this.meshApPassword,
  });

  Home copyWith({
    String? homeId,
    String? name,
    String? timezone,
    List<int>? homeKey,
    String? meshId,
    String? meshApPassword,
  }) {
    return Home(
      homeId: homeId ?? this.homeId,
      name: name ?? this.name,
      timezone: timezone ?? this.timezone,
      homeKey: homeKey ?? this.homeKey,
      meshId: meshId ?? this.meshId,
      meshApPassword: meshApPassword ?? this.meshApPassword,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'homeId': homeId,
      'name': name,
      'timezone': timezone,
      'homeKey': homeKey,
      'meshId': meshId,
      'meshApPassword': meshApPassword,
    };
  }

  factory Home.fromJson(Map<String, dynamic> json) {
    return Home(
      homeId: json['homeId'] as String,
      name: json['name'] as String,
      timezone: (json['timezone'] as String?) ?? 'Asia/Kolkata',
      homeKey: (json['homeKey'] as List<dynamic>).map((e) => e as int).toList(),
      meshId: json['meshId'] as String,
      meshApPassword: json['meshApPassword'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Home &&
          runtimeType == other.runtimeType &&
          homeId == other.homeId &&
          name == other.name &&
          timezone == other.timezone &&
          listEquals(homeKey, other.homeKey) &&
          meshId == other.meshId &&
          meshApPassword == other.meshApPassword;

  @override
  int get hashCode => Object.hash(
        homeId,
        name,
        timezone,
        Object.hashAll(homeKey),
        meshId,
        meshApPassword,
      );

  @override
  String toString() => 'Home(homeId: $homeId, name: $name, tz: $timezone)';
}
