import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/auth_service.dart';
import '../core/auth/biometric_auth_service.dart';
import '../core/security/role_permissions.dart';
import '../data/secure_store/secure_key_store.dart';
import '../domain/models/member.dart';

// Providers for dependencies
final secureKeyStoreProvider = Provider<SecureKeyStore>((ref) {
  return const FlutterSecureKeyStore();
});

final authServiceProvider = Provider<AuthService>((ref) {
  final secureStorage = ref.watch(secureKeyStoreProvider);
  return FakeAuthService(secureStorage: secureStorage);
});

final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  final secureStorage = ref.watch(secureKeyStoreProvider);
  return LocalAuthBiometricService(secureStorage: secureStorage);
});

@immutable
class AuthState {
  final String? userId;
  final String? email;
  final String? displayName;
  final String? token; // Current short-lived access token
  final String? currentHomeId;
  final MemberRole currentRole;
  final bool isAuthenticated;
  final bool isLoading;
  final bool isBiometricLocked;
  final String? errorMessage;

  const AuthState({
    this.userId,
    this.email,
    this.displayName,
    this.token,
    this.currentHomeId,
    this.currentRole = MemberRole.owner,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.isBiometricLocked = false,
    this.errorMessage,
  });

  bool can(RoleAction action) => RolePermissions.can(currentRole, action);

  void assertCan(RoleAction action) => RolePermissions.assertCan(currentRole, action);

  AuthState copyWith({
    String? userId,
    String? email,
    String? displayName,
    String? token,
    String? currentHomeId,
    MemberRole? currentRole,
    bool? isAuthenticated,
    bool? isLoading,
    bool? isBiometricLocked,
    String? errorMessage,
  }) {
    return AuthState(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      token: token ?? this.token,
      currentHomeId: currentHomeId ?? this.currentHomeId,
      currentRole: currentRole ?? this.currentRole,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      isBiometricLocked: isBiometricLocked ?? this.isBiometricLocked,
      errorMessage: errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          email == other.email &&
          displayName == other.displayName &&
          token == other.token &&
          currentHomeId == other.currentHomeId &&
          currentRole == other.currentRole &&
          isAuthenticated == other.isAuthenticated &&
          isLoading == other.isLoading &&
          isBiometricLocked == other.isBiometricLocked &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
        userId,
        email,
        displayName,
        token,
        currentHomeId,
        currentRole,
        isAuthenticated,
        isLoading,
        isBiometricLocked,
        errorMessage,
      );

  @override
  String toString() =>
      'AuthState(user: $userId, role: ${currentRole.name}, auth: $isAuthenticated, home: $currentHomeId)';
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthService _authService;
  late final BiometricAuthService _biometricService;

  @override
  AuthState build() {
    _authService = ref.watch(authServiceProvider);
    _biometricService = ref.watch(biometricAuthServiceProvider);
    return const AuthState();
  }

  /// Backward-compatible login method for tests and direct state seeding.
  void login({
    required String userId,
    required String token,
    String? defaultHomeId,
    MemberRole role = MemberRole.owner,
  }) {
    state = AuthState(
      userId: userId,
      email: '$userId@example.com',
      displayName: userId,
      token: token,
      currentHomeId: defaultHomeId,
      currentRole: role,
      isAuthenticated: true,
    );
  }

  /// Full OIDC credential login with secure storage session creation.
  Future<bool> loginWithCredentials({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final session = await _authService.login(email: email, password: password);
      final isLockEnabled = await _biometricService.isAppLockEnabled();

      state = AuthState(
        userId: session.userId,
        email: session.email,
        displayName: session.displayName,
        token: session.accessToken,
        currentHomeId: session.homeIds.isNotEmpty ? session.homeIds.first : null,
        currentRole: session.currentRole,
        isAuthenticated: true,
        isLoading: false,
        isBiometricLocked: isLockEnabled,
      );
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'An unexpected error occurred.');
      return false;
    }
  }

  /// Account registration flow.
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final session = await _authService.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );

      state = AuthState(
        userId: session.userId,
        email: session.email,
        displayName: session.displayName,
        token: session.accessToken,
        currentHomeId: session.homeIds.isNotEmpty ? session.homeIds.first : null,
        currentRole: session.currentRole,
        isAuthenticated: true,
        isLoading: false,
      );
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Registration failed.');
      return false;
    }
  }

  /// Unlocks app with biometric authentication.
  Future<bool> unlockWithBiometrics() async {
    final success = await _biometricService.authenticate();
    if (success) {
      state = state.copyWith(isBiometricLocked: false);
    }
    return success;
  }

  /// Updates active home and role.
  void selectHome(String homeId, {MemberRole role = MemberRole.owner}) {
    state = state.copyWith(currentHomeId: homeId, currentRole: role);
  }

  /// Updates active user role within current home.
  void setRole(MemberRole role) {
    state = state.copyWith(currentRole: role);
  }

  /// Logs out and purges tokens from secure storage.
  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState();
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
