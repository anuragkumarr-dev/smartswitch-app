import 'package:flutter/foundation.dart';

/// Represents an individual relay switch/gang on a physical device (Blueprint §1 & §4.3).
@immutable
class Gang {
  final String gangId; // e.g. "gang1", "gang2"
  final String name;
  final bool isOn;

  const Gang({
    required this.gangId,
    required this.name,
    this.isOn = false,
  });

  Gang copyWith({
    String? gangId,
    String? name,
    bool? isOn,
  }) {
    return Gang(
      gangId: gangId ?? this.gangId,
      name: name ?? this.name,
      isOn: isOn ?? this.isOn,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gangId': gangId,
      'name': name,
      'isOn': isOn,
    };
  }

  factory Gang.fromJson(Map<String, dynamic> json) {
    return Gang(
      gangId: json['gangId'] as String,
      name: json['name'] as String,
      isOn: (json['isOn'] as bool?) ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Gang &&
          runtimeType == other.runtimeType &&
          gangId == other.gangId &&
          name == other.name &&
          isOn == other.isOn;

  @override
  int get hashCode => Object.hash(gangId, name, isOn);

  @override
  String toString() => 'Gang(id: $gangId, name: $name, on: $isOn)';
}
