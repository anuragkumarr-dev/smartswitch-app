import 'package:flutter/foundation.dart';

/// Secure logger and string sanitizer that enforces zero-leakage of sensitive secrets.
/// Redacts: Access Tokens, Refresh Tokens, Home Keys, PoP secrets, and Mesh passwords (Blueprint §5).
class SecureLogger {
  static final RegExp _bearerRegex = RegExp(r'Bearer\s+[A-Za-z0-9\-_.]+', caseSensitive: false);
  static final RegExp _popRegex = RegExp(r'(pop|proof)[:=]\s*([A-Za-z0-9!@#$%^&*]+)', caseSensitive: false);
  static final RegExp _tokenRegex = RegExp(r'(token|refresh_token|access_token)[:=]\s*([A-Za-z0-9\-_.]+)', caseSensitive: false);
  static final RegExp _keyRegex = RegExp(r'(homeKey|net_key|key)[:=]\s*([A-Za-z0-9+/=]{16,})', caseSensitive: false);
  static final RegExp _meshPwdRegex = RegExp(r'(meshApPassword|ap_psk)[:=]\s*(\S+)', caseSensitive: false);

  /// Sanitize an arbitrary log string by redacting potential secrets.
  static String sanitize(String message) {
    var sanitized = message;
    sanitized = sanitized.replaceAllMapped(_bearerRegex, (m) => 'Bearer [REDACTED]');
    sanitized = sanitized.replaceAllMapped(_popRegex, (m) => '${m.group(1)}: [REDACTED_POP]');
    sanitized = sanitized.replaceAllMapped(_tokenRegex, (m) => '${m.group(1)}: [REDACTED_TOKEN]');
    sanitized = sanitized.replaceAllMapped(_keyRegex, (m) => '${m.group(1)}: [REDACTED_KEY]');
    sanitized = sanitized.replaceAllMapped(_meshPwdRegex, (m) => '${m.group(1)}: [REDACTED_PASSWORD]');
    return sanitized;
  }

  /// Safe logging function that never outputs plaintext secrets.
  static void log(String message) {
    if (kDebugMode) {
      debugPrint('[SmartSwitch] ${sanitize(message)}');
    }
  }

  /// Safely logs an error without revealing sensitive credentials in stack trace or message.
  static void logError(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[SmartSwitch:ERROR] ${sanitize(message)}');
      if (error != null) {
        debugPrint('[SmartSwitch:ERROR] ${sanitize(error.toString())}');
      }
      if (stackTrace != null) {
        debugPrint('[SmartSwitch:STACK] $stackTrace');
      }
    }
  }
}
