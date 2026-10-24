import 'package:flutter/foundation.dart';

/// Defines the operational capabilities of a switch hardware/firmware device.
/// For standard ESP-WIFI-MESH nodes, all features (schedules, timers, backlight, OTA) are available.
/// For legacy Blynk bridge devices, only basic on/off and online state are supported.
@immutable
class DeviceCapabilities {
  final bool supportsOnOff;
  final bool supportsSchedules;
  final bool supportsCountdown;
  final bool supportsBacklight;
  final bool supportsPowerOnBehaviour;
  final bool supportsTouchLock;
  final bool supportsBleOnboarding;
  final bool supportsMeshTopologyDetail;

  const DeviceCapabilities({
    this.supportsOnOff = true,
    this.supportsSchedules = true,
    this.supportsCountdown = true,
    this.supportsBacklight = true,
    this.supportsPowerOnBehaviour = true,
    this.supportsTouchLock = true,
    this.supportsBleOnboarding = true,
    this.supportsMeshTopologyDetail = true,
  });

  /// Full capabilities for standard SmartSwitch ESP-WIFI-MESH hardware.
  static const DeviceCapabilities full = DeviceCapabilities();

  /// Minimal capabilities for prototype Blynk bridge nodes.
  /// Supports only on/off and online status; schedules, countdown, backlight, etc. are hidden.
  static const DeviceCapabilities blynkBasic = DeviceCapabilities(
    supportsOnOff: true,
    supportsSchedules: false,
    supportsCountdown: false,
    supportsBacklight: false,
    supportsPowerOnBehaviour: false,
    supportsTouchLock: false,
    supportsBleOnboarding: false,
    supportsMeshTopologyDetail: false,
  );

  Map<String, dynamic> toJson() => {
        'supportsOnOff': supportsOnOff,
        'supportsSchedules': supportsSchedules,
        'supportsCountdown': supportsCountdown,
        'supportsBacklight': supportsBacklight,
        'supportsPowerOnBehaviour': supportsPowerOnBehaviour,
        'supportsTouchLock': supportsTouchLock,
        'supportsBleOnboarding': supportsBleOnboarding,
        'supportsMeshTopologyDetail': supportsMeshTopologyDetail,
      };

  factory DeviceCapabilities.fromJson(Map<String, dynamic> json) =>
      DeviceCapabilities(
        supportsOnOff: json['supportsOnOff'] as bool? ?? true,
        supportsSchedules: json['supportsSchedules'] as bool? ?? true,
        supportsCountdown: json['supportsCountdown'] as bool? ?? true,
        supportsBacklight: json['supportsBacklight'] as bool? ?? true,
        supportsPowerOnBehaviour:
            json['supportsPowerOnBehaviour'] as bool? ?? true,
        supportsTouchLock: json['supportsTouchLock'] as bool? ?? true,
        supportsBleOnboarding: json['supportsBleOnboarding'] as bool? ?? true,
        supportsMeshTopologyDetail:
            json['supportsMeshTopologyDetail'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceCapabilities &&
          runtimeType == other.runtimeType &&
          supportsOnOff == other.supportsOnOff &&
          supportsSchedules == other.supportsSchedules &&
          supportsCountdown == other.supportsCountdown &&
          supportsBacklight == other.supportsBacklight &&
          supportsPowerOnBehaviour == other.supportsPowerOnBehaviour &&
          supportsTouchLock == other.supportsTouchLock &&
          supportsBleOnboarding == other.supportsBleOnboarding &&
          supportsMeshTopologyDetail == other.supportsMeshTopologyDetail;

  @override
  int get hashCode => Object.hash(
        supportsOnOff,
        supportsSchedules,
        supportsCountdown,
        supportsBacklight,
        supportsPowerOnBehaviour,
        supportsTouchLock,
        supportsBleOnboarding,
        supportsMeshTopologyDetail,
      );
}
