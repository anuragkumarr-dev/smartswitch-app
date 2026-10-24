import 'dart:async';
import '../../data/secure_store/secure_key_store.dart';
import '../../domain/models/member.dart';

/// User authentication session data (Blueprint §5).
class AuthSession {
  final String userId;
  final String email;
  final String displayName;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final List<String> homeIds;
  final MemberRole currentRole;

  const AuthSession({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.homeIds = const [],
    this.currentRole = MemberRole.owner,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  AuthSession copyWith({
    String? userId,
    String? email,
    String? displayName,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    List<String>? homeIds,
    MemberRole? currentRole,
  }) {
    return AuthSession(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      homeIds: homeIds ?? this.homeIds,
      currentRole: currentRole ?? this.currentRole,
    );
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => 'AuthException: $message';
}

/// Abstract AuthService for OIDC-style authentication (Blueprint §5).
abstract interface class AuthService {
  Future<AuthSession> login({
    required String email,
    required String password,
  });

  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  /// Rotates the refresh token and returns a new session with fresh short-lived access token.
  Future<AuthSession> refreshToken(String refreshToken);

  Future<void> logout();

  Future<AuthSession?> restoreSession();
}

/// In-memory fake AuthService for testing and development.
/// Features full refresh-token rotation and secure storage synchronization.
class FakeAuthService implements AuthService {
  final SecureKeyStore secureStorage;
  final Map<String, _FakeUser> _users = {};
  final Set<String> _validRefreshTokens = {};

  AuthSession? _currentSession;

  FakeAuthService({
    required this.secureStorage,
    Map<String, String>? initialUsers,
  }) {
    // Seed default test user
    _users['user@example.com'] = _FakeUser(
      userId: 'usr_main_1',
      email: 'user@example.com',
      password: 'password123',
      displayName: 'Main User',
      homeIds: ['h_main'],
      role: MemberRole.owner,
    );

    if (initialUsers != null) {
      initialUsers.forEach((email, pwd) {
        _users[email] = _FakeUser(
          userId: 'usr_${email.hashCode.abs()}',
          email: email,
          password: pwd,
          displayName: email.split('@').first,
          homeIds: ['h_main'],
          role: MemberRole.member,
        );
      });
    }
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final user = _users[email];
    if (user == null || user.password != password) {
      throw const AuthException('Invalid email or password.');
    }

    return _generateAndStoreSession(user);
  }

  @override
  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (_users.containsKey(email)) {
      throw const AuthException('An account with this email already exists.');
    }

    final newUser = _FakeUser(
      userId: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      password: password,
      displayName: displayName,
      homeIds: ['h_${DateTime.now().millisecondsSinceEpoch}'],
      role: MemberRole.owner,
    );
    _users[email] = newUser;

    return _generateAndStoreSession(newUser);
  }

  @override
  Future<AuthSession> refreshToken(String oldRefreshToken) async {
    if (!_validRefreshTokens.contains(oldRefreshToken)) {
      throw const AuthException('Refresh token is invalid or has expired.');
    }

    // Refresh token rotation: Invalidate old refresh token immediately!
    _validRefreshTokens.remove(oldRefreshToken);

    final user = _currentSession != null
        ? _users[_currentSession!.email] ?? _users.values.first
        : _users.values.first;

    return _generateAndStoreSession(user);
  }

  @override
  Future<void> logout() async {
    _currentSession = null;
    _validRefreshTokens.clear();
    // Critical security control: purge all tokens and keys from secure storage on logout
    await secureStorage.clearTokens();
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final refreshToken = await secureStorage.getRefreshToken();
    if (refreshToken == null || !_validRefreshTokens.contains(refreshToken)) {
      return null;
    }

    final accessToken = await secureStorage.getAccessToken();
    final expiry = await secureStorage.getTokenExpiry();

    if (accessToken != null && expiry != null && DateTime.now().isBefore(expiry)) {
      final user = _users.values.first;
      _currentSession = AuthSession(
        userId: user.userId,
        email: user.email,
        displayName: user.displayName,
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiry,
        homeIds: user.homeIds,
        currentRole: user.role,
      );
      return _currentSession;
    }

    // Access token expired, attempt refresh
    try {
      return await this.refreshToken(refreshToken);
    } catch (_) {
      await secureStorage.clearTokens();
      return null;
    }
  }

  static int _tokenSequence = 0;

  Future<AuthSession> _generateAndStoreSession(_FakeUser user) async {
    final now = DateTime.now();
    final seq = _tokenSequence++;
    final accessToken = 'at_${now.microsecondsSinceEpoch}_${seq}_${user.userId}';
    final newRefreshToken = 'rt_${now.microsecondsSinceEpoch}_${seq}_${user.userId}';
    final expiresAt = now.add(const Duration(minutes: 15)); // Short-lived 15m access token

    _validRefreshTokens.add(newRefreshToken);

    final session = AuthSession(
      userId: user.userId,
      email: user.email,
      displayName: user.displayName,
      accessToken: accessToken,
      refreshToken: newRefreshToken,
      expiresAt: expiresAt,
      homeIds: user.homeIds,
      currentRole: user.role,
    );

    _currentSession = session;

    // Save tokens securely in platform keychain / encrypted store
    await secureStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: newRefreshToken,
      expiresAt: expiresAt,
    );

    return session;
  }
}

class _FakeUser {
  final String userId;
  final String email;
  final String password;
  final String displayName;
  final List<String> homeIds;
  final MemberRole role;

  _FakeUser({
    required this.userId,
    required this.email,
    required this.password,
    required this.displayName,
    required this.homeIds,
    required this.role,
  });
}
