import 'package:flutter_test/flutter_test.dart';
import 'package:smartswitch_app/core/security/key_rotation_manager.dart';
import 'package:smartswitch_app/data/secure_store/secure_key_store.dart';

void main() {
  group('Key Rotation & Reconnection (Blueprint §2.4 & §5)', () {
    late FakeSecureKeyStore secureStorage;
    late KeyRotationManager keyRotationManager;
    bool reconnectInvoked = false;
    List<int>? rotatedKeyReceived;
    int? rotatedKeyIdReceived;

    final initialKey = List<int>.filled(32, 1);
    final newKey = List<int>.filled(32, 2);

    setUp(() async {
      secureStorage = FakeSecureKeyStore();
      reconnectInvoked = false;
      rotatedKeyReceived = null;
      rotatedKeyIdReceived = null;

      // Seed initial key_id = 1
      await secureStorage.saveHomeKey(
        homeId: 'h_main',
        homeKey: initialKey,
        keyId: 1,
      );

      keyRotationManager = KeyRotationManager(
        secureStorage: secureStorage,
        onKeyRotated: (k, id) async {
          reconnectInvoked = true;
          rotatedKeyReceived = k;
          rotatedKeyIdReceived = id;
        },
      );
    });

    test('Stale or identical key_id does not trigger rotation', () async {
      final rotated = await keyRotationManager.checkAndApplyKeyRotation(
        homeId: 'h_main',
        incomingKeyId: 1,
        newKeyBytes: newKey,
      );

      expect(rotated, isFalse);
      expect(reconnectInvoked, isFalse);
      expect(await secureStorage.getHomeKeyId('h_main'), 1);
      expect(await secureStorage.getHomeKey('h_main'), initialKey);
    });

    test('New key_id updates secure storage and triggers session re-derivation and reconnect', () async {
      final rotated = await keyRotationManager.checkAndApplyKeyRotation(
        homeId: 'h_main',
        incomingKeyId: 2,
        newKeyBytes: newKey,
      );

      expect(rotated, isTrue);
      expect(reconnectInvoked, isTrue);
      expect(rotatedKeyIdReceived, 2);
      expect(rotatedKeyReceived, newKey);

      // Verify updated in secure storage
      expect(await secureStorage.getHomeKeyId('h_main'), 2);
      expect(await secureStorage.getHomeKey('h_main'), newKey);
    });
  });
}
