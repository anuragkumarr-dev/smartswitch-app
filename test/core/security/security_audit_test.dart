import 'package:flutter_test/flutter_test.dart';
import 'package:smartswitch_app/core/security/secure_logger.dart';

void main() {
  group('Security Audit: Zero Secret Leakage in Logs (Blueprint §5)', () {
    test('Redacts Bearer authorization tokens', () {
      const rawLog = 'HTTP GET /devices with header Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.signature';
      final sanitized = SecureLogger.sanitize(rawLog);

      expect(sanitized, isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')));
      expect(sanitized, contains('Bearer [REDACTED]'));
    });

    test('Redacts Proof-of-Possession (PoP) secrets', () {
      const rawLog = 'Connected to BLE switch. Handshake PoP: TopSecretPoP123! in progress';
      final sanitized = SecureLogger.sanitize(rawLog);

      expect(sanitized, isNot(contains('TopSecretPoP123!')));
      expect(sanitized, contains('[REDACTED_POP]'));
    });

    test('Redacts access tokens and refresh tokens in key-value format', () {
      const rawLog = 'Auth payload received: refresh_token: rt_secret_refresh_987654321';
      final sanitized = SecureLogger.sanitize(rawLog);

      expect(sanitized, isNot(contains('rt_secret_refresh_987654321')));
      expect(sanitized, contains('[REDACTED_TOKEN]'));
    });

    test('Redacts Home Keys and wrapped network keys', () {
      const rawLog = 'Received config envelope: net_key: 0102030405060708090a0b0c0d0e0f10';
      final sanitized = SecureLogger.sanitize(rawLog);

      expect(sanitized, isNot(contains('0102030405060708090a0b0c0d0e0f10')));
      expect(sanitized, contains('[REDACTED_KEY]'));
    });

    test('Redacts mesh AP passwords', () {
      const rawLog = 'Pushing Wi-Fi mesh configuration meshApPassword: SuperSecretMeshPassword123!';
      final sanitized = SecureLogger.sanitize(rawLog);

      expect(sanitized, isNot(contains('SuperSecretMeshPassword123!')));
      expect(sanitized, contains('[REDACTED_PASSWORD]'));
    });
  });
}
