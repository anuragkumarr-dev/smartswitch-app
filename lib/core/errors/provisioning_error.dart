import 'package:flutter/foundation.dart';

/// Blueprint §2.4 failure taxonomy and error types for smart switch provisioning.
enum ProvisioningFailureType {
  /// Scanned QR code format does not match SW1:<productId>:<deviceId>:<PoP>.
  invalidQr,

  /// Required permissions (Camera or Bluetooth/Location) were denied by the user.
  permissionDenied,

  /// Bluetooth adapter is turned off or not available on phone.
  bluetoothDisabled,

  /// Targeted BLE scan timed out without discovering the matching switch.
  deviceNotFound,

  /// The flow encountered an advertisement whose device ID did not match the QR.
  /// Connection was refused by policy.
  deviceIdMismatch,

  /// Bluetooth GATT connection to the switch failed.
  connectionFailed,

  /// SRP6a Security 2 handshake failed due to wrong Proof of Possession (PoP).
  handshakeFailedWrongPop,

  /// Failed to read device info or capabilities after establishing session.
  deviceInfoFailed,

  /// Device was already provisioned and belongs to another home.
  alreadyBound,

  /// Backend token service failed to produce an activation token.
  tokenRequestFailed,

  /// Switch rejected the activation token during or after provisioning.
  tokenRejected,

  /// Wi-Fi authentication failed (wrong password).
  wifiAuthFailed,

  /// Wi-Fi router / SSID not found or only 5 GHz available.
  routerNotFound,

  /// Switch could not reach or join the mesh within timeout.
  meshJoinTimeout,

  /// Unexpected or unclassified failure.
  unknown,
}

/// Typed exception for provisioning operations containing user-facing messages
/// and recovery actions directly mapped from the blueprint §2.4 failure table.
@immutable
class ProvisioningException implements Exception {
  final ProvisioningFailureType type;
  final String message;
  final String userMessage;
  final String recoveryAction;
  final Object? cause;

  const ProvisioningException({
    required this.type,
    required this.message,
    required this.userMessage,
    required this.recoveryAction,
    this.cause,
  });

  /// Factory constructors for each failure from blueprint §2.4:

  /// Wrong PoP / handshake fails
  factory ProvisioningException.handshakeFailedWrongPop([Object? cause]) {
    return ProvisioningException(
      type: ProvisioningFailureType.handshakeFailedWrongPop,
      message: 'SRP6a handshake failed: proof of possession rejected',
      userMessage: "This code doesn't match the device",
      recoveryAction: 'Re-scan QR, check sticker',
      cause: cause,
    );
  }

  /// Wi-Fi auth failed
  factory ProvisioningException.wifiAuthFailed([Object? cause]) {
    return ProvisioningException(
      type: ProvisioningFailureType.wifiAuthFailed,
      message: 'Device reported Wi-Fi authentication failure',
      userMessage: 'Wi-Fi password rejected',
      recoveryAction: 'Re-enter password, device keeps provisioning mode',
      cause: cause,
    );
  }

  /// Router not found or 5 GHz only
  factory ProvisioningException.routerNotFound([Object? cause]) {
    return ProvisioningException(
      type: ProvisioningFailureType.routerNotFound,
      message: 'Target Wi-Fi router/AP was not found',
      userMessage: 'No 2.4 GHz network found',
      recoveryAction: 'Explain 2.4 GHz requirement',
      cause: cause,
    );
  }

  /// Mesh join timeout
  factory ProvisioningException.meshJoinTimeout([Object? cause]) {
    return ProvisioningException(
      type: ProvisioningFailureType.meshJoinTimeout,
      message: 'Timeout attempting to join root or parent mesh node',
      userMessage: "Device can't reach your other switches",
      recoveryAction: 'Move closer to an existing node, retry',
      cause: cause,
    );
  }

  /// Token rejected
  factory ProvisioningException.tokenRejected([Object? cause]) {
    return ProvisioningException(
      type: ProvisioningFailureType.tokenRejected,
      message: 'Activation token was rejected or expired',
      userMessage: 'Setup expired',
      recoveryAction: 'Fetch a new token, resend config',
      cause: cause,
    );
  }

  /// Device already bound
  factory ProvisioningException.alreadyBound([Object? cause]) {
    return ProvisioningException(
      type: ProvisioningFailureType.alreadyBound,
      message: 'Device has existing credentials and is bound to a home',
      userMessage: 'Already added to another home',
      recoveryAction: 'Owner must reset and remove it',
      cause: cause,
    );
  }

  /// Invalid QR payload
  factory ProvisioningException.invalidQr(String rawPayload, [Object? cause]) {
    return ProvisioningException(
      type: ProvisioningFailureType.invalidQr,
      message: 'Malformed QR payload: "$rawPayload"',
      userMessage: 'Invalid QR code',
      recoveryAction: 'Ensure you scan a valid SmartSwitch QR code (SW1:<productId>:<deviceId>:<PoP>)',
      cause: cause,
    );
  }

  /// Device mismatch
  factory ProvisioningException.deviceIdMismatch({
    required String expectedDeviceId,
    required String discoveredDeviceId,
  }) {
    return ProvisioningException(
      type: ProvisioningFailureType.deviceIdMismatch,
      message: 'Device ID mismatch: expected $expectedDeviceId, found $discoveredDeviceId',
      userMessage: 'Security violation: switch ID does not match QR code',
      recoveryAction: 'Make sure you are scanning the QR code physically affixed to this device.',
    );
  }

  /// Device not found
  factory ProvisioningException.deviceNotFound(String deviceId, [Object? cause]) {
    return ProvisioningException(
      type: ProvisioningFailureType.deviceNotFound,
      message: 'BLE scan timed out searching for device "$deviceId"',
      userMessage: 'Switch not found nearby',
      recoveryAction: 'Ensure switch is powered on and within range, and try again',
      cause: cause,
    );
  }

  /// Permissions denied
  factory ProvisioningException.permissionDenied(String missingPermission) {
    return ProvisioningException(
      type: ProvisioningFailureType.permissionDenied,
      message: 'Required permission was denied: $missingPermission',
      userMessage: 'Required permission denied',
      recoveryAction: 'Grant Bluetooth and Camera permissions in device settings to proceed',
    );
  }

  /// Bluetooth disabled
  factory ProvisioningException.bluetoothDisabled() {
    return const ProvisioningException(
      type: ProvisioningFailureType.bluetoothDisabled,
      message: 'Bluetooth adapter is powered off',
      userMessage: 'Bluetooth is turned off',
      recoveryAction: 'Turn on Bluetooth in device quick settings',
    );
  }

  /// Connection failed
  factory ProvisioningException.connectionFailed(String deviceId, [Object? cause]) {
    return ProvisioningException(
      type: ProvisioningFailureType.connectionFailed,
      message: 'Failed to establish BLE connection with $deviceId',
      userMessage: 'Could not connect to switch',
      recoveryAction: 'Move closer to the switch and try again',
      cause: cause,
    );
  }

  /// Token request failed
  factory ProvisioningException.tokenRequestFailed([Object? cause]) {
    return ProvisioningException(
      type: ProvisioningFailureType.tokenRequestFailed,
      message: 'Cloud service failed to issue activation token',
      userMessage: 'Could not obtain activation token',
      recoveryAction: 'Check your internet connection and try again',
      cause: cause,
    );
  }

  /// Generic/unknown failure
  factory ProvisioningException.unknown(String detail, [Object? cause]) {
    return ProvisioningException(
      type: ProvisioningFailureType.unknown,
      message: detail,
      userMessage: 'Provisioning failed unexpectedly',
      recoveryAction: 'Power cycle the switch and retry',
      cause: cause,
    );
  }

  @override
  String toString() => 'ProvisioningException($type): $message (User: "$userMessage")';
}
