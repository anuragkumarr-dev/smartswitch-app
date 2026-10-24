import 'dart:async';
import 'package:dio/dio.dart';
import '../../data/secure_store/secure_key_store.dart';
import '../../domain/models/member.dart';
import 'auth_service.dart';

/// Configuration for OIDC Identity Provider (Blueprint §5).
/// Read from environment/gitignored config; never hardcoded in source.
class OidcConfig {
  final String issuer;
  final String clientId;
  final String redirectUri;
  final List<String> scopes;
  final String tokenEndpoint;
  final String userInfoEndpoint;

  const OidcConfig({
    this.issuer = 'https://auth.example.com/oauth2',
    this.clientId = 'smartswitch-app-client',
    this.redirectUri = 'smartswitch://oauth-callback',
    this.scopes = const ['openid', 'profile', 'email', 'offline_access'],
    this.tokenEndpoint = 'https://auth.example.com/oauth2/token',
    this.userInfoEndpoint = 'https://auth.example.com/oauth2/userinfo',
  });

  /// Factory loading configuration from a gitignored environment map.
  factory OidcConfig.fromEnv(Map<String, String> env) {
    return OidcConfig(
      issuer: env['OIDC_ISSUER'] ?? 'https://auth.example.com/oauth2',
      clientId: env['OIDC_CLIENT_ID'] ?? 'smartswitch-app-client',
      redirectUri: env['OIDC_REDIRECT_URI'] ?? 'smartswitch://oauth-callback',
      scopes: env['OIDC_SCOPES']?.split(' ') ?? const ['openid', 'profile', 'email', 'offline_access'],
      tokenEndpoint: env['OIDC_TOKEN_ENDPOINT'] ?? 'https://auth.example.com/oauth2/token',
      userInfoEndpoint: env['OIDC_USERINFO_ENDPOINT'] ?? 'https://auth.example.com/oauth2/userinfo',
    );
  }
}

/// Real implementation stub for OIDC-based authentication (Blueprint §5).
/// Connects to real OIDC providers when backend is ready, reading config from gitignored env.
class OidcAuthServiceStub implements AuthService {
  final OidcConfig config;
  final SecureKeyStore secureStorage;
  final Dio _dio;

  OidcAuthServiceStub({
    required this.config,
    required this.secureStorage,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    // In production, launches OAuth2 Authorization Code Flow with PKCE.
    // For the stub, interacts with the mock token endpoint.
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        config.tokenEndpoint,
        data: {
          'grant_type': 'password',
          'client_id': config.clientId,
          'username': email,
          'password': password,
          'scope': config.scopes.join(' '),
        },
      );

      final data = response.data ?? {};
      final accessToken = data['access_token'] as String? ?? 'stub_access_token';
      final refreshToken = data['refresh_token'] as String? ?? 'stub_refresh_token';
      final expiresIn = data['expires_in'] as int? ?? 900;
      final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

      await secureStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
      );

      return AuthSession(
        userId: 'usr_${email.hashCode.abs()}',
        email: email,
        displayName: email.split('@').first,
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
        currentRole: MemberRole.owner,
      );
    } catch (e) {
      throw AuthException('OIDC login failed: $e');
    }
  }

  @override
  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return login(email: email, password: password);
  }

  @override
  Future<AuthSession> refreshToken(String refreshToken) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        config.tokenEndpoint,
        data: {
          'grant_type': 'refresh_token',
          'client_id': config.clientId,
          'refresh_token': refreshToken,
        },
      );

      final data = response.data ?? {};
      final newAccessToken = data['access_token'] as String? ?? 'new_access_token';
      final newRefreshToken = data['refresh_token'] as String? ?? 'new_refresh_token';
      final expiresIn = data['expires_in'] as int? ?? 900;
      final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

      await secureStorage.saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
        expiresAt: expiresAt,
      );

      return AuthSession(
        userId: 'usr_current',
        email: 'user@example.com',
        displayName: 'User',
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
        expiresAt: expiresAt,
      );
    } catch (e) {
      throw AuthException('OIDC refresh token failed: $e');
    }
  }

  @override
  Future<void> logout() async {
    await secureStorage.clearTokens();
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final refreshToken = await secureStorage.getRefreshToken();
    if (refreshToken == null) return null;

    final accessToken = await secureStorage.getAccessToken();
    final expiry = await secureStorage.getTokenExpiry();

    if (accessToken != null && expiry != null && DateTime.now().isBefore(expiry)) {
      return AuthSession(
        userId: 'usr_restored',
        email: 'user@example.com',
        displayName: 'Restored User',
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiry,
      );
    }

    try {
      return await this.refreshToken(refreshToken);
    } catch (_) {
      await secureStorage.clearTokens();
      return null;
    }
  }
}
