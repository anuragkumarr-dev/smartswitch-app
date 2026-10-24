import 'package:flutter_test/flutter_test.dart';
import 'package:smartswitch_app/core/auth/auth_service.dart';
import 'package:smartswitch_app/core/auth/biometric_auth_service.dart';
import 'package:smartswitch_app/data/secure_store/secure_key_store.dart';

void main() {
  group('AuthService & Secure Storage Lifecycle (Blueprint §5)', () {
    late FakeSecureKeyStore secureStorage;
    late FakeAuthService authService;
    late FakeBiometricAuthService biometricService;

    setUp(() {
      secureStorage = FakeSecureKeyStore();
      authService = FakeAuthService(secureStorage: secureStorage);
      biometricService = FakeBiometricAuthService(secureStorage: secureStorage);
    });

    test('Login saves short-lived access token and refresh token into secure storage', () async {
      final session = await authService.login(
        email: 'user@example.com',
        password: 'password123',
      );

      expect(session.userId, isNotEmpty);
      expect(session.accessToken, startsWith('at_'));
      expect(session.refreshToken, startsWith('rt_'));
      expect(session.isExpired, isFalse);

      // Verify stored in secure storage
      expect(await secureStorage.getAccessToken(), session.accessToken);
      expect(await secureStorage.getRefreshToken(), session.refreshToken);
      expect(await secureStorage.getTokenExpiry(), isNotNull);
    });

    test('Refresh-token rotation issues new access and refresh tokens, invalidating the old one', () async {
      final initialSession = await authService.login(
        email: 'user@example.com',
        password: 'password123',
      );
      final oldRefreshToken = initialSession.refreshToken;

      // Rotate refresh token
      final rotatedSession = await authService.refreshToken(oldRefreshToken);

      expect(rotatedSession.accessToken, isNot(initialSession.accessToken));
      expect(rotatedSession.refreshToken, isNot(oldRefreshToken));

      // Secure storage must be updated with the rotated tokens
      expect(await secureStorage.getAccessToken(), rotatedSession.accessToken);
      expect(await secureStorage.getRefreshToken(), rotatedSession.refreshToken);

      // Attempting to reuse old refresh token must be rejected (Token Replay Prevention)
      await expectLater(
        authService.refreshToken(oldRefreshToken),
        throwsA(isA<AuthException>()),
      );
    });

    test('Logout clears all tokens from secure storage', () async {
      await authService.login(
        email: 'user@example.com',
        password: 'password123',
      );

      expect(await secureStorage.getAccessToken(), isNotNull);
      expect(await secureStorage.getRefreshToken(), isNotNull);

      // Logout
      await authService.logout();

      // Secure storage must be empty of tokens
      expect(await secureStorage.getAccessToken(), isNull);
      expect(await secureStorage.getRefreshToken(), isNull);
      expect(await secureStorage.getTokenExpiry(), isNull);
    });

    test('Biometric app-lock configuration persists in secure storage and authenticates', () async {
      expect(await biometricService.isAppLockEnabled(), isFalse);

      await biometricService.setAppLockEnabled(true);
      expect(await biometricService.isAppLockEnabled(), isTrue);

      final authSuccess = await biometricService.authenticate();
      expect(authSuccess, isTrue);

      await biometricService.setAppLockEnabled(false);
      expect(await biometricService.isAppLockEnabled(), isFalse);
    });
  });
}
