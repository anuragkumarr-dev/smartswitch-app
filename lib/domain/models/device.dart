import 'package:flutter/foundation.dart';
import 'gang.dart';
import 'shadow.dart';

/// Represents a physical SmartSwitch device (Blueprint §1, §3.1, §4.3).
@immutable
class Device {
  final String deviceId;
  final String homeId;
  final String roomId;
  final String name;
  final String product;
  final int gangsCount; // 1 to 4
  final List<Gang> gangs;
  final String fwVersion;
  final String gatewayId; // Current Root switch routing gateway
  final Shadow shadow;

  const Device({
    required this.deviceId,
    required this.homeId,
    required this.roomId,
    required this.name,
    required this.product,
    required this.gangsCount,
    this.gangs = const [],
    this.fwVersion = '1.0.0',
    required this.gatewayId,
    this.shadow = const Shadow(),
  });

  Device copyWith({
    String? deviceId,
    String? homeId,
    String? roomId,
    String? name,
    String? product,
    int? gangsCount,
    List<Gang>? gangs,
    String? fwVersion,
    String? gatewayId,
    Shadow? shadow,
  }) {
    return Device(
      deviceId: deviceId ?? this.deviceId,
      homeId: homeId ?? this.homeId,
      roomId: roomId ?? this.roomId,
      name: name ?? this.name,
      product: product ?? this.product,
      gangsCount: gangsCount ?? this.gangsCount,
      gangs: gangs ?? this.gangs,
      fwVersion: fwVersion ?? this.fwVersion,
      gatewayId: gatewayId ?? this.gatewayId,
      shadow: shadow ?? this.shadow,
    );
  }

  /// Whether all gangs in this device are turned ON
  bool get isAllOn => gangs.isNotEmpty && gangs.every((g) => g.isOn);

  /// Whether any gang in this device is turned ON
  bool get isAnyOn => gangs.any((g) => g.isOn);

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'homeId': homeId,
      'roomId': roomId,
      'name': name,
      'product': product,
      'gangsCount': gangsCount,
      'gangs': gangs.map((g) => g.toJson()).toList(),
      'fwVersion': fwVersion,
      'gatewayId': gatewayId,
      'shadow': shadow.toJson(),
    };
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    final gangsList = (json['gangs'] as List<dynamic>?)
            ?.map((e) => Gang.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final shadowJson = json['shadow'] as Map<String, dynamic>?;

    return Device(
      deviceId: json['deviceId'] as String,
      homeId: json['homeId'] as String,
      roomId: json['roomId'] as String,
      name: json['name'] as String,
      product: (json['product'] as String?) ?? 'SW1-1G',
      gangsCount: (json['gangsCount'] as num?)?.toInt() ?? 1,
      gangs: gangsList,
      fwVersion: (json['fwVersion'] as String?) ?? '1.0.0',
      gatewayId: json['gatewayId'] as String,
      shadow: shadowJson != null ? Shadow.fromJson(shadowJson) : const Shadow(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          homeId == other.homeId &&
          roomId == other.roomId &&
          name == other.name &&
          product == other.product &&
          gangsCount == other.gangsCount &&
          listEquals(gangs, other.gangs) &&
          fwVersion == other.fwVersion &&
          gatewayId == other.gatewayId &&
          shadow == other.shadow;

  @override
  int get hashCode => Object.hash(
        deviceId,
        homeId,
        roomId,
        name,
        product,
        gangsCount,
        Object.hashAll(gangs),
        fwVersion,
        gatewayId,
        shadow,
      );

  @override
  String toString() => 'Device($deviceId, name: $name, gangs: ${gangs.length}, root: $gatewayId)';
}
