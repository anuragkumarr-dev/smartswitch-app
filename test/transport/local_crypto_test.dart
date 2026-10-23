import 'package:flutter_test/flutter_test.dart';
import 'package:smartswitch_app/transport/crypto/local_crypto.dart';

void main() {
  group('LocalCrypto (HKDF + AES-256-GCM)', () {
    late LocalCrypto crypto;
    late List<int> mockHomeKey;

    setUp(() {
      crypto = LocalCrypto();
      mockHomeKey = List<int>.generate(32, (i) => i * 3);
    });

    test('derives identical session key from same nonces and home key', () async {
      final clientNonce = LocalCrypto.generateRandomBytes(16);
      final serverNonce = LocalCrypto.generateRandomBytes(16);

      final key1 = await crypto.deriveSessionKey(
        homeKeyBytes: mockHomeKey,
        clientNonce: clientNonce,
        serverNonce: serverNonce,
      );

      final key2 = await crypto.deriveSessionKey(
        homeKeyBytes: mockHomeKey,
        clientNonce: clientNonce,
        serverNonce: serverNonce,
      );

      final bytes1 = await key1.extractBytes();
      final bytes2 = await key2.extractBytes();
      expect(bytes1, equals(bytes2));
      expect(bytes1.length, 32);
    });

    test('derives different session key if client or server nonce differs', () async {
      final clientNonce1 = LocalCrypto.generateRandomBytes(16);
      final clientNonce2 = LocalCrypto.generateRandomBytes(16);
      final serverNonce = LocalCrypto.generateRandomBytes(16);

      final key1 = await crypto.deriveSessionKey(
        homeKeyBytes: mockHomeKey,
        clientNonce: clientNonce1,
        serverNonce: serverNonce,
      );

      final key2 = await crypto.deriveSessionKey(
        homeKeyBytes: mockHomeKey,
        clientNonce: clientNonce2,
        serverNonce: serverNonce,
      );

      final bytes1 = await key1.extractBytes();
      final bytes2 = await key2.extractBytes();
      expect(bytes1, isNot(equals(bytes2)));
    });

    test('encrypts and decrypts string messages correctly with AES-GCM', () async {
      final clientNonce = LocalCrypto.generateRandomBytes(16);
      final serverNonce = LocalCrypto.generateRandomBytes(16);

      final key = await crypto.deriveSessionKey(
        homeKeyBytes: mockHomeKey,
        clientNonce: clientNonce,
        serverNonce: serverNonce,
      );

      const plaintext = '{"gang1": {"on": true}, "cmdId": "c_12345"}';
      final nonce = LocalCrypto.createNonce(LocalCrypto.generateRandomBytes(8), 1);

      final encrypted = await crypto.encryptString(
        text: plaintext,
        secretKey: key,
        nonce: nonce,
      );

      // Verify payload structure: 12-byte nonce + ciphertext + 16-byte tag
      expect(encrypted.length, greaterThan(12 + 16));

      final decrypted = await crypto.decryptString(
        packedPayload: encrypted,
        secretKey: key,
      );

      expect(decrypted, plaintext);
    });

    test('fails decryption when ciphertext or tag is tampered with', () async {
      final clientNonce = LocalCrypto.generateRandomBytes(16);
      final serverNonce = LocalCrypto.generateRandomBytes(16);

      final key = await crypto.deriveSessionKey(
        homeKeyBytes: mockHomeKey,
        clientNonce: clientNonce,
        serverNonce: serverNonce,
      );

      final nonce = LocalCrypto.createNonce(LocalCrypto.generateRandomBytes(8), 1);
      final encrypted = await crypto.encryptString(
        text: 'test_payload',
        secretKey: key,
        nonce: nonce,
      );

      // Tamper with one byte in the ciphertext
      final tampered = List<int>.from(encrypted);
      tampered[tampered.length - 1] ^= 0xFF;

      expect(
        () => crypto.decryptString(packedPayload: tampered, secretKey: key),
        throwsA(anything),
      );
    });
  });
}
