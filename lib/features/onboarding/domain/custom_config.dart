import 'package:flutter/foundation.dart';

/// Configuration payload sent to ESP-IDF custom endpoint "sw-config" (Blueprint §2.4).
@immutable
class CustomConfigPayload {
  final int version;
  final MeshConfig mesh;
  final HomeConfig home;
  final ActivationConfig activation;
  final DeviceConfig device;

  const CustomConfigPayload({
    this.version = 1,
    required this.mesh,
    required this.home,
    required this.activation,
    required this.device,
  });

  Map<String, dynamic> toJson() => {
        'v': version,
        'mesh': mesh.toJson(),
        'home': home.toJson(),
        'activation': activation.toJson(),
        'device': device.toJson(),
      };
}

@immutable
class MeshConfig {
  final String id;
  final String apPsk;
  final int maxLayer;

  const MeshConfig({
    required this.id,
    required this.apPsk,
    this.maxLayer = 6,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'ap_psk': apPsk,
        'max_layer': maxLayer,
      };
}

@immutable
class HomeConfig {
  final String id;
  final String netKeyWrapped;
  final int keyId;

  const HomeConfig({
    required this.id,
    required this.netKeyWrapped,
    this.keyId = 1,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'net_key_wrapped': netKeyWrapped,
        'key_id': keyId,
      };
}

@immutable
class ActivationConfig {
  final String token;
  final String cloud;
  final String region;

  const ActivationConfig({
    required this.token,
    required this.cloud,
    required this.region,
  });

  Map<String, dynamic> toJson() => {
        'token': token,
        'cloud': cloud,
        'region': region,
      };
}

@immutable
class DeviceConfig {
  final String name;
  final String roomId;

  const DeviceConfig({
    required this.name,
    required this.roomId,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'room_id': roomId,
      };
}
