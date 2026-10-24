import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../../data/secure_store/secure_key_store.dart';

/// Service managing optional biometric application lock (Blueprint §5).
abstract interface class BiometricAuthService {
  Future<bool> isBiometricsAvailable();
  Future<bool> authenticate({String reason = 'Authenticate to access SmartSwitch'});
  Future<bool> isAppLockEnabled();
  Future<void> setAppLockEnabled(bool enabled);
}

/// Production implementation of [BiometricAuthService] using `local_auth`.
class LocalAuthBiometricService implements BiometricAuthService {
  final LocalAuthentication _localAuth;
  final SecureKeyStore _secureStorage;

  LocalAuthBiometricService({
    LocalAuthentication? localAuth,
    required this._secureStorage,
  }) : _localAuth = localAuth ?? LocalAuthentication();

  @override
  Future<bool> isBiometricsAvailable() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> authenticate({String reason = 'Authenticate to access SmartSwitch'}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
      );
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> isAppLockEnabled() => _secureStorage.isBiometricsEnabled();

  @override
  Future<void> setAppLockEnabled(bool enabled) => _secureStorage.setBiometricsEnabled(enabled);
}

/// Fake implementation of [BiometricAuthService] for tests and simulation.
class FakeBiometricAuthService implements BiometricAuthService {
  final SecureKeyStore secureStorage;
  bool isAvailable;
  bool shouldSucceed;

  FakeBiometricAuthService({
    required this.secureStorage,
    this.isAvailable = true,
    this.shouldSucceed = true,
  });

  @override
  Future<bool> isBiometricsAvailable() async => isAvailable;

  @override
  Future<bool> authenticate({String reason = 'Authenticate to access SmartSwitch'}) async {
    if (!isAvailable) return false;
    return shouldSucceed;
  }

  @override
  Future<bool> isAppLockEnabled() => secureStorage.isBiometricsEnabled();

  @override
  Future<void> setAppLockEnabled(bool enabled) => secureStorage.setBiometricsEnabled(enabled);
}
