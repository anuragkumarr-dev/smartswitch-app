import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartswitch_app/core/auth/auth_service.dart';
import 'package:smartswitch_app/data/api_client/certificate_pinning_interceptor.dart';
import 'package:smartswitch_app/data/api_client/token_refresh_interceptor.dart';
import 'package:smartswitch_app/data/secure_store/secure_key_store.dart';

void main() {
  group('Certificate Pinning & Interceptor (Blueprint §5)', () {
    final validCertDer = utf8.encode('CERT_DER_VALID_LEAF');
    final backupCertDer = utf8.encode('CERT_DER_BACKUP_LEAF');
    final rogueCertDer = utf8.encode('ROGUE_CERT_DER');

    late String validPin;
    late String backupPin;

    setUp(() async {
      final validHash = await Sha256().hash(validCertDer);
      validPin = 'sha256/${base64Encode(validHash.bytes)}';

      final backupHash = await Sha256().hash(backupCertDer);
      backupPin = 'sha256/${base64Encode(backupHash.bytes)}';
    });

    test('Valid certificate matching primary or backup pin passes validation', () async {
      final config = CertificatePinningConfig(
        primaryPin: validPin,
        backupPin: backupPin,
      );

      expect(await config.matches(validCertDer), isTrue);
      expect(await config.matches(backupCertDer), isTrue);
    });

    test('Wrong certificate is rejected by CertificatePinningConfig', () async {
      final config = CertificatePinningConfig(
        primaryPin: validPin,
        backupPin: backupPin,
      );

      expect(await config.matches(rogueCertDer), isFalse);
    });

    test('CertificatePinningInterceptor rejects request with invalid cert', () async {
      final config = CertificatePinningConfig(
        primaryPin: validPin,
        backupPin: backupPin,
      );

      final dio = Dio();
      dio.interceptors.add(CertificatePinningInterceptor(config: config));

      // Attempt request presenting rogue cert
      try {
        await dio.get<void>(
          'https://example.com/api',
          options: Options(
            extra: {'cert_der': rogueCertDer},
          ),
        );
        fail('Must reject invalid certificate');
      } on DioException catch (e) {
        expect(e.type, DioExceptionType.badCertificate);
        expect(e.error, isA<CertificatePinningException>());
      }
    });
  });

  group('TokenRefreshInterceptor 401 Auto-Refresh', () {
    late FakeSecureKeyStore secureStorage;
    late FakeAuthService authService;

    setUp(() async {
      secureStorage = FakeSecureKeyStore();
      authService = FakeAuthService(secureStorage: secureStorage);
      await authService.login(email: 'user@example.com', password: 'password123');
    });

    test('TokenRefreshInterceptor injects Bearer header and rotates on 401', () async {
      final dio = Dio();
      final interceptor = TokenRefreshInterceptor(
        dio: dio,
        secureStorage: secureStorage,
        authService: authService,
      );

      final initialToken = await secureStorage.getAccessToken();
      expect(initialToken, isNotNull);

      final reqOptions = RequestOptions(path: '/devices');
      final handler = _TestRequestInterceptorHandler();

      await interceptor.onRequest(reqOptions, handler);
      expect(reqOptions.headers['Authorization'], 'Bearer $initialToken');
    });
  });
}

class _TestRequestInterceptorHandler extends RequestInterceptorHandler {
  RequestOptions? options;

  @override
  void next(RequestOptions requestOptions) {
    options = requestOptions;
  }
}
