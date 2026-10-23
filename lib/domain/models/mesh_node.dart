import 'package:flutter/foundation.dart';

/// Role of a node inside the ESP-WIFI-MESH network (Blueprint §0 & §4.4).
enum MeshRole {
  root,
  node;

  bool get isRoot => this == MeshRole.root;

  static MeshRole fromString(String val) {
    return val.toLowerCase() == 'root' ? MeshRole.root : MeshRole.node;
  }
}

/// Link signal quality category based on RSSI (Blueprint §4.4).
enum LinkQuality {
  excellent, // > -60 dBm
  fair, // -60 to -75 dBm
  weak; // < -75 dBm

  static LinkQuality fromRssi(int rssi) {
    if (rssi > -60) return LinkQuality.excellent;
    if (rssi >= -75) return LinkQuality.fair;
    return LinkQuality.weak;
  }
}

/// Represents an active mesh node in the mesh network topology (Blueprint §4.4).
@immutable
class MeshNode {
  final String deviceId;
  final String name;
  final String roomId;
  final MeshRole role;
  final int layer; // 1 for Root, 2+ for sub-nodes
  final String? parentId;
  final int childrenCount;
  final int rssiToParent; // dBm, e.g. -58
  final int uptimeSeconds;
  final DateTime lastSeen;
  final String fwVersion;

  const MeshNode({
    required this.deviceId,
    required this.name,
    required this.roomId,
    required this.role,
    this.layer = 1,
    this.parentId,
    this.childrenCount = 0,
    this.rssiToParent = -50,
    this.uptimeSeconds = 0,
    required this.lastSeen,
    this.fwVersion = '1.0.0',
  });

  MeshNode copyWith({
    String? deviceId,
    String? name,
    String? roomId,
    MeshRole? role,
    int? layer,
    String? parentId,
    int? childrenCount,
    int? rssiToParent,
    int? uptimeSeconds,
    DateTime? lastSeen,
    String? fwVersion,
  }) {
    return MeshNode(
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      roomId: roomId ?? this.roomId,
      role: role ?? this.role,
      layer: layer ?? this.layer,
      parentId: parentId ?? this.parentId,
      childrenCount: childrenCount ?? this.childrenCount,
      rssiToParent: rssiToParent ?? this.rssiToParent,
      uptimeSeconds: uptimeSeconds ?? this.uptimeSeconds,
      lastSeen: lastSeen ?? this.lastSeen,
      fwVersion: fwVersion ?? this.fwVersion,
    );
  }

  LinkQuality get linkQuality => LinkQuality.fromRssi(rssiToParent);

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'name': name,
      'roomId': roomId,
      'role': role.name,
      'layer': layer,
      'parentId': parentId,
      'childrenCount': childrenCount,
      'rssiToParent': rssiToParent,
      'uptimeSeconds': uptimeSeconds,
      'lastSeen': lastSeen.toIso8601String(),
      'fwVersion': fwVersion,
    };
  }

  factory MeshNode.fromJson(Map<String, dynamic> json) {
    return MeshNode(
      deviceId: json['deviceId'] as String,
      name: json['name'] as String,
      roomId: json['roomId'] as String,
      role: MeshRole.fromString(json['role'] as String? ?? 'node'),
      layer: (json['layer'] as num?)?.toInt() ?? 1,
      parentId: json['parentId'] as String?,
      childrenCount: (json['childrenCount'] as num?)?.toInt() ?? 0,
      rssiToParent: (json['rssiToParent'] as num?)?.toInt() ?? -60,
      uptimeSeconds: (json['uptimeSeconds'] as num?)?.toInt() ?? 0,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : DateTime.now(),
      fwVersion: (json['fwVersion'] as String?) ?? '1.0.0',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeshNode &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          name == other.name &&
          roomId == other.roomId &&
          role == other.role &&
          layer == other.layer &&
          parentId == other.parentId &&
          childrenCount == other.childrenCount &&
          rssiToParent == other.rssiToParent &&
          uptimeSeconds == other.uptimeSeconds &&
          lastSeen == other.lastSeen &&
          fwVersion == other.fwVersion;

  @override
  int get hashCode => Object.hash(
        deviceId,
        name,
        roomId,
        role,
        layer,
        parentId,
        childrenCount,
        rssiToParent,
        uptimeSeconds,
        lastSeen,
        fwVersion,
      );

  @override
  String toString() =>
      'MeshNode($deviceId (${role.name}), layer: $layer, parent: $parentId, rssi: $rssiToParent dBm)';
}
