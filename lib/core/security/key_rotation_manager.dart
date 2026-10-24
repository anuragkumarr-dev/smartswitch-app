import 'dart:async';
import '../../data/secure_store/secure_key_store.dart';
import 'secure_logger.dart';

/// Callback invoked after key rotation to re-derive session keys and reconnect LocalTransport.
typedef KeyRotationCallback = Future<void> Function(List<int> newKey, int newKeyId);

/// Manages cryptographic Home Key rotation (Blueprint §2.4 & §5).
/// When `key_id` advances, updates secure storage, re-derives local session key,
/// and securely triggers LocalTransport reconnection without exposing secrets.
class KeyRotationManager {
  final SecureKeyStore secureStorage;
  final KeyRotationCallback? onKeyRotated;

  KeyRotationManager({
    required this.secureStorage,
    this.onKeyRotated,
  });

  /// Evaluates incoming `key_id`. If newer than stored `key_id`, rotates the key.
  Future<bool> checkAndApplyKeyRotation({
    required String homeId,
    required int incomingKeyId,
    required List<int> newKeyBytes,
  }) async {
    final currentKeyId = await secureStorage.getHomeKeyId(homeId) ?? 0;

    if (incomingKeyId <= currentKeyId) {
      // Current key is already up to date
      return false;
    }

    SecureLogger.log('Key rotation triggered for home $homeId: key_id $currentKeyId -> $incomingKeyId');

    // 1. Persist new homeKey and new key_id to hardware-backed secure storage
    await secureStorage.saveHomeKey(
      homeId: homeId,
      homeKey: newKeyBytes,
      keyId: incomingKeyId,
    );

    // 2. Re-derive session key and reconnect LocalTransport
    if (onKeyRotated != null) {
      await onKeyRotated!(newKeyBytes, incomingKeyId);
    }

    SecureLogger.log('Key rotation successfully completed for key_id $incomingKeyId');
    return true;
  }
}
