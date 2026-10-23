import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Cryptographic operations for LocalTransport (Blueprint §3.4 and docs/protocol.md §4).
/// Provides HKDF session key derivation from the Home Key and AES-256-GCM app-layer encryption.
class LocalCrypto {
  final AesGcm _aesGcm;
  final Hkdf _hkdf;

  LocalCrypto({
    AesGcm? aesGcm,
    Hkdf? hkdf,
  })  : _aesGcm = aesGcm ?? AesGcm.with256bits(),
        _hkdf = hkdf ??
            Hkdf(
              hmac: Hmac.sha256(),
              outputLength: 32,
            );

  static final Random _secureRandom = Random.secure();

  /// Generates cryptographically secure random bytes of given [length].
  static Uint8List generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _secureRandom.nextInt(256);
    }
    return bytes;
  }

  /// Converts bytes to a hex string.
  static String bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Parses a hex string to Uint8List.
  static Uint8List hexToBytes(String hex) {
    final clean = hex.replaceAll(' ', '').trim();
    final result = Uint8List(clean.length ~/ 2);
    for (var i = 0; i < clean.length; i += 2) {
      result[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  /// Derives a 32-byte session key from the Home Key using HKDF-SHA256 with client and server nonces.
  Future<SecretKey> deriveSessionKey({
    required List<int> homeKeyBytes,
    required List<int> clientNonce,
    required List<int> serverNonce,
  }) async {
    final salt = Uint8List.fromList([...clientNonce, ...serverNonce]);
    final info = utf8.encode('smartswitch-local-session');

    final secretKey = SecretKey(homeKeyBytes);

    final derivedKeyBytes = await _hkdf.deriveKey(
      secretKey: secretKey,
      nonce: salt,
      info: info,
    );

    return derivedKeyBytes;
  }

  /// Constructs a 12-byte AES-GCM nonce using an 8-byte prefix and a 4-byte monotonic counter.
  static Uint8List createNonce(List<int> prefix8Bytes, int counter) {
    final nonce = Uint8List(12);
    nonce.setRange(0, 8, prefix8Bytes.sublist(0, 8));
    final byteData = ByteData.sublistView(nonce, 8, 12);
    byteData.setUint32(0, counter, Endian.big);
    return nonce;
  }

  /// Encrypts plaintext bytes using AES-256-GCM.
  /// Output format: [12-byte Nonce] [Ciphertext] [16-byte MAC Tag].
  Future<Uint8List> encrypt({
    required List<int> plaintext,
    required SecretKey secretKey,
    required List<int> nonce,
  }) async {
    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    final nonceBytes = secretBox.nonce;
    final cipherText = secretBox.cipherText;
    final macBytes = secretBox.mac.bytes;

    final output = Uint8List(nonceBytes.length + cipherText.length + macBytes.length);
    output.setRange(0, nonceBytes.length, nonceBytes);
    output.setRange(nonceBytes.length, nonceBytes.length + cipherText.length, cipherText);
    output.setRange(nonceBytes.length + cipherText.length, output.length, macBytes);

    return output;
  }

  /// Decrypts a packed AES-256-GCM payload formatted as:
  /// [12-byte Nonce] [Ciphertext] [16-byte MAC Tag].
  Future<Uint8List> decrypt({
    required List<int> packedPayload,
    required SecretKey secretKey,
  }) async {
    const nonceLength = 12;
    const macLength = 16;

    if (packedPayload.length < nonceLength + macLength) {
      throw ArgumentError('Payload too short for AES-GCM message');
    }

    final nonce = packedPayload.sublist(0, nonceLength);
    final cipherText = packedPayload.sublist(nonceLength, packedPayload.length - macLength);
    final macBytes = packedPayload.sublist(packedPayload.length - macLength);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final decrypted = await _aesGcm.decrypt(
      secretBox,
      secretKey: secretKey,
    );

    return Uint8List.fromList(decrypted);
  }

  /// Convenience method to encrypt a UTF-8 string.
  Future<Uint8List> encryptString({
    required String text,
    required SecretKey secretKey,
    required List<int> nonce,
  }) {
    return encrypt(
      plaintext: utf8.encode(text),
      secretKey: secretKey,
      nonce: nonce,
    );
  }

  /// Convenience method to decrypt a UTF-8 string.
  Future<String> decryptString({
    required List<int> packedPayload,
    required SecretKey secretKey,
  }) async {
    final decryptedBytes = await decrypt(
      packedPayload: packedPayload,
      secretKey: secretKey,
    );
    return utf8.decode(decryptedBytes);
  }
}
