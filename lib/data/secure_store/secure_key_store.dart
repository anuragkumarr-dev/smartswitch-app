import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstract secure key and token storage interface (Blueprint §5).
/// Enforces hardware-backed encryption (iOS Keychain / Android KeyStore).
abstract interface class SecureKeyStore {
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  });

  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<DateTime?> getTokenExpiry();
  Future<void> clearTokens();

  Future<void> saveHomeKey({
    required String homeId,
    required List<int> homeKey,
    required int keyId,
  });

  Future<List<int>?> getHomeKey(String homeId);
  Future<int?> getHomeKeyId(String homeId);
  Future<void> deleteHomeKey(String homeId);

  Future<void> setBiometricsEnabled(bool enabled);
  Future<bool> isBiometricsEnabled();

  // Blynk Prototype Configuration (Blueprint §5 & Blynk Bridge)
  Future<void> saveBlynkConfig({
    required String token,
    required String region,
  });
  Future<String?> getBlynkToken();
  Future<String?> getBlynkRegion();
  Future<void> clearBlynkConfig();

  // App Mode (Demo vs Blynk)
  Future<void> saveAppMode(String mode);
  Future<String?> getAppMode();

  Future<void> clearAll();
}

/// Production implementation using [FlutterSecureStorage].
class FlutterSecureKeyStore implements SecureKeyStore {
  final FlutterSecureStorage _storage;

  const FlutterSecureKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(resetOnError: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  static const String _keyAccessToken = 'auth_access_token';
  static const String _keyRefreshToken = 'auth_refresh_token';
  static const String _keyTokenExpiry = 'auth_token_expiry';
  static const String _keyBiometricsEnabled = 'setting_biometrics_enabled';
  static const String _keyBlynkToken = 'blynk_auth_token';
  static const String _keyBlynkRegion = 'blynk_region';
  static const String _keyAppMode = 'app_mode_setting';

  String _homeKeyPrefix(String homeId) => 'home_key_$homeId';
  String _homeKeyIdPrefix(String homeId) => 'home_key_id_$homeId';

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
    await _storage.write(
      key: _keyTokenExpiry,
      value: expiresAt.toIso8601String(),
    );
  }

  @override
  Future<String?> getAccessToken() => _storage.read(key: _keyAccessToken);

  @override
  Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);

  @override
  Future<DateTime?> getTokenExpiry() async {
    final str = await _storage.read(key: _keyTokenExpiry);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  @override
  Future<void> clearTokens() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyTokenExpiry);
  }

  @override
  Future<void> saveHomeKey({
    required String homeId,
    required List<int> homeKey,
    required int keyId,
  }) async {
    final hexKey = base64Encode(homeKey);
    await _storage.write(key: _homeKeyPrefix(homeId), value: hexKey);
    await _storage.write(key: _homeKeyIdPrefix(homeId), value: keyId.toString());
  }

  @override
  Future<List<int>?> getHomeKey(String homeId) async {
    final val = await _storage.read(key: _homeKeyPrefix(homeId));
    if (val == null) return null;
    try {
      return base64Decode(val);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int?> getHomeKeyId(String homeId) async {
    final val = await _storage.read(key: _homeKeyIdPrefix(homeId));
    if (val == null) return null;
    return int.tryParse(val);
  }

  @override
  Future<void> deleteHomeKey(String homeId) async {
    await _storage.delete(key: _homeKeyPrefix(homeId));
    await _storage.delete(key: _homeKeyIdPrefix(homeId));
  }

  @override
  Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(
      key: _keyBiometricsEnabled,
      value: enabled ? 'true' : 'false',
    );
  }

  @override
  Future<bool> isBiometricsEnabled() async {
    final val = await _storage.read(key: _keyBiometricsEnabled);
    return val == 'true';
  }

  @override
  Future<void> saveBlynkConfig({
    required String token,
    required String region,
  }) async {
    await _storage.write(key: _keyBlynkToken, value: token);
    await _storage.write(key: _keyBlynkRegion, value: region);
  }

  @override
  Future<String?> getBlynkToken() => _storage.read(key: _keyBlynkToken);

  @override
  Future<String?> getBlynkRegion() => _storage.read(key: _keyBlynkRegion);

  @override
  Future<void> clearBlynkConfig() async {
    await _storage.delete(key: _keyBlynkToken);
    await _storage.delete(key: _keyBlynkRegion);
  }

  @override
  Future<void> saveAppMode(String mode) async {
    await _storage.write(key: _keyAppMode, value: mode);
  }

  @override
  Future<String?> getAppMode() => _storage.read(key: _keyAppMode);

  @override
  Future<void> clearAll() => _storage.deleteAll();
}

/// In-memory fake implementation of [SecureKeyStore] for unit and widget testing.
class FakeSecureKeyStore implements SecureKeyStore {
  final Map<String, String> _data = {};

  static const String _keyAccessToken = 'auth_access_token';
  static const String _keyRefreshToken = 'auth_refresh_token';
  static const String _keyTokenExpiry = 'auth_token_expiry';
  static const String _keyBiometricsEnabled = 'setting_biometrics_enabled';
  static const String _keyBlynkToken = 'blynk_auth_token';
  static const String _keyBlynkRegion = 'blynk_region';
  static const String _keyAppMode = 'app_mode_setting';

  String _homeKeyPrefix(String homeId) => 'home_key_$homeId';
  String _homeKeyIdPrefix(String homeId) => 'home_key_id_$homeId';

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) async {
    _data[_keyAccessToken] = accessToken;
    _data[_keyRefreshToken] = refreshToken;
    _data[_keyTokenExpiry] = expiresAt.toIso8601String();
  }

  @override
  Future<String?> getAccessToken() async => _data[_keyAccessToken];

  @override
  Future<String?> getRefreshToken() async => _data[_keyRefreshToken];

  @override
  Future<DateTime?> getTokenExpiry() async {
    final str = _data[_keyTokenExpiry];
    return str != null ? DateTime.tryParse(str) : null;
  }

  @override
  Future<void> clearTokens() async {
    _data.remove(_keyAccessToken);
    _data.remove(_keyRefreshToken);
    _data.remove(_keyTokenExpiry);
  }

  @override
  Future<void> saveHomeKey({
    required String homeId,
    required List<int> homeKey,
    required int keyId,
  }) async {
    _data[_homeKeyPrefix(homeId)] = base64Encode(homeKey);
    _data[_homeKeyIdPrefix(homeId)] = keyId.toString();
  }

  @override
  Future<List<int>?> getHomeKey(String homeId) async {
    final val = _data[_homeKeyPrefix(homeId)];
    if (val == null) return null;
    return base64Decode(val);
  }

  @override
  Future<int?> getHomeKeyId(String homeId) async {
    final val = _data[_homeKeyIdPrefix(homeId)];
    return val != null ? int.tryParse(val) : null;
  }

  @override
  Future<void> deleteHomeKey(String homeId) async {
    _data.remove(_homeKeyPrefix(homeId));
    _data.remove(_homeKeyIdPrefix(homeId));
  }

  @override
  Future<void> setBiometricsEnabled(bool enabled) async {
    _data[_keyBiometricsEnabled] = enabled ? 'true' : 'false';
  }

  @override
  Future<bool> isBiometricsEnabled() async {
    return _data[_keyBiometricsEnabled] == 'true';
  }

  @override
  Future<void> saveBlynkConfig({
    required String token,
    required String region,
  }) async {
    _data[_keyBlynkToken] = token;
    _data[_keyBlynkRegion] = region;
  }

  @override
  Future<String?> getBlynkToken() async => _data[_keyBlynkToken];

  @override
  Future<String?> getBlynkRegion() async => _data[_keyBlynkRegion];

  @override
  Future<void> clearBlynkConfig() async {
    _data.remove(_keyBlynkToken);
    _data.remove(_keyBlynkRegion);
  }

  @override
  Future<void> saveAppMode(String mode) async {
    _data[_keyAppMode] = mode;
  }

  @override
  Future<String?> getAppMode() async => _data[_keyAppMode];

  @override
  Future<void> clearAll() async {
    _data.clear();
  }
}
