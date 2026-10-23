import 'package:flutter/foundation.dart';

/// Represents a Room entity for organizing devices (Blueprint §1 & §3.1).
@immutable
class Room {
  final String roomId;
  final String homeId;
  final String name;
  final int order;

  const Room({
    required this.roomId,
    required this.homeId,
    required this.name,
    this.order = 0,
  });

  Room copyWith({
    String? roomId,
    String? homeId,
    String? name,
    int? order,
  }) {
    return Room(
      roomId: roomId ?? this.roomId,
      homeId: homeId ?? this.homeId,
      name: name ?? this.name,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'homeId': homeId,
      'name': name,
      'order': order,
    };
  }

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      roomId: json['roomId'] as String,
      homeId: json['homeId'] as String,
      name: json['name'] as String,
      order: (json['order'] as int?) ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Room &&
          runtimeType == other.runtimeType &&
          roomId == other.roomId &&
          homeId == other.homeId &&
          name == other.name &&
          order == other.order;

  @override
  int get hashCode => Object.hash(roomId, homeId, name, order);

  @override
  String toString() => 'Room(roomId: $roomId, name: $name, order: $order)';
}
