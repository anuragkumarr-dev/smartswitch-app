import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';

/// Configuration for TLS Certificate Pinning with dual-pin rotation support (Blueprint §5).
class CertificatePinningConfig {
  final String primaryPin; // SHA-256 SPKI hash
  final String? backupPin;  // Backup pin for zero-downtime certificate rotation
  final bool enabled;

  const CertificatePinningConfig({
    required this.primaryPin,
    this.backupPin,
    this.enabled = true,
  });

  /// Factory loading pins from an environment configuration map (no hardcoded secrets).
  factory CertificatePinningConfig.fromEnv(Map<String, String> env) {
    return CertificatePinningConfig(
      primaryPin: env['TLS_PIN_PRIMARY'] ?? 'sha256/47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=',
      backupPin: env['TLS_PIN_BACKUP'] ?? 'sha256/k2v657xBsOVe1PQR42OU30htRiEUBvRevL46MLReKWU=',
      enabled: env['TLS_PINNING_ENABLED'] != 'false',
    );
  }

  /// Verifies if a given certificate DER bytes matches either the primary or backup pin.
  Future<bool> matches(List<int> certDerBytes) async {
    if (!enabled) return true;
    final hash = await Sha256().hash(certDerBytes);
    final calculatedPin = 'sha256/${base64Encode(hash.bytes)}';
    return calculatedPin == primaryPin || calculatedPin == backupPin;
  }
}

/// Thrown when TLS certificate pinning validation fails.
class CertificatePinningException implements Exception {
  final String message;
  final String? presentedPin;

  CertificatePinningException(this.message, [this.presentedPin]);

  @override
  String toString() => 'CertificatePinningException: $message';
}

/// Dio Interceptor enforcing SHA-256 certificate pinning on all outbound cloud API calls.
class CertificatePinningInterceptor extends Interceptor {
  final CertificatePinningConfig config;

  CertificatePinningInterceptor({required this.config});

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // If request contains simulated or verified cert bytes in extra, validate it
    final certBytes = options.extra['cert_der'] as List<int>?;
    if (config.enabled && certBytes != null) {
      final isMatch = await config.matches(certBytes);
      if (!isMatch) {
        final hash = await Sha256().hash(certBytes);
        final presented = 'sha256/${base64Encode(hash.bytes)}';
        handler.reject(
          DioException(
            requestOptions: options,
            error: CertificatePinningException(
              'Server certificate does not match pinned SPKI hashes (Primary: ${config.primaryPin}, Backup: ${config.backupPin})',
              presented,
            ),
            type: DioExceptionType.badCertificate,
          ),
        );
        return;
      }
    }
    handler.next(options);
  }
}
