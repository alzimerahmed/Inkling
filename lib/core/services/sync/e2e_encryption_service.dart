import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Client-side (end-to-end) encryption for sync payloads.
///
/// Backup archives are encrypted on-device with AES-256-GCM before they are
/// uploaded to the user's own WebDAV/Nextcloud server, so the server only ever
/// stores ciphertext. The encryption key is derived from a user passphrase via
/// PBKDF2-HMAC-SHA256 (deterministic for a given passphrase + salt, so any
/// device holding the same passphrase and salt can derive the same key).
///
/// Payload layout (single blob, self-describing):
///
/// ```
/// [8B magic "IKLE2E\x01"][16B salt][12B nonce][16B GCM tag][ciphertext...]
/// ```
///
/// Embedding salt + nonce + tag in the payload means decryption only needs the
/// passphrase — no side-channel metadata has to be synced.
///
/// Uses package:cryptography (Apache-2.0, pure-Dart fallback) — no proprietary
/// or GMS-bound deps, keeping the community flavor F-Droid compatible.
class E2eEncryptionService {
  E2eEncryptionService();

  /// Versioned magic header: "IKLE2E" + format version byte 0x01.
  static const List<int> magicBytes = [0x49, 0x4B, 0x4C, 0x45, 0x32, 0x45, 0x01];

  static const int saltLengthBytes = 16;
  static const int nonceLengthBytes = 12;
  static const int tagLengthBytes = 16;
  static final int headerLengthBytes = magicBytes.length + saltLengthBytes + nonceLengthBytes;

  /// OWASP-recommended floor for PBKDF2-HMAC-SHA256 is 600k iterations for
  /// password storage; for a passphrase-derived *encryption* key used on
  /// mobile, 150k keeps unlock responsive while remaining far above legacy
  /// defaults. Tunable in one place if hardware allows raising it later.
  static const int pbkdf2Iterations = 150000;

  static const int _keyBits = 256;

  final AesGcm _aesGcm = AesGcm.with256bits();
  final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: pbkdf2Iterations,
    bits: _keyBits,
  );

  /// Deterministic: the same (passphrase, salt) pair always yields the same
  /// 32-byte key (unit-tested).
  Future<Uint8List> deriveKey({required String passphrase, required List<int> salt}) async {
    final SecretKey key = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  /// Encrypts [plaintext] into the self-describing payload format above.
  ///
  /// [salt] and [nonce] default to fresh cryptographically-secure random
  /// values; tests may inject fixed ones for determinism.
  Future<Uint8List> encrypt({
    required List<int> plaintext,
    required String passphrase,
    List<int>? salt,
    List<int>? nonce,
  }) async {
    final Random secureRandom = Random.secure();
    final List<int> usedSalt = salt ?? List<int>.generate(saltLengthBytes, (_) => secureRandom.nextInt(256));
    final List<int> usedNonce = nonce ?? List<int>.generate(nonceLengthBytes, (_) => secureRandom.nextInt(256));

    if (usedSalt.length != saltLengthBytes) throw ArgumentError('salt must be $saltLengthBytes bytes');
    if (usedNonce.length != nonceLengthBytes) throw ArgumentError('nonce must be $nonceLengthBytes bytes');

    final Uint8List key = await deriveKey(passphrase: passphrase, salt: usedSalt);
    final SecretBox box = await _aesGcm.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: usedNonce,
    );

    final BytesBuilder builder = BytesBuilder();
    builder.add(magicBytes);
    builder.add(usedSalt);
    builder.add(usedNonce);
    builder.add(box.mac.bytes);
    builder.add(box.cipherText);
    return builder.toBytes();
  }

  /// Decrypts a payload produced by [encrypt]. Throws [FormatException] on a
  /// malformed header and [SecretBoxAuthenticationError] on a wrong passphrase
  /// or tampered ciphertext (AES-GCM authenticates the whole payload).
  Future<Uint8List> decrypt({required List<int> encrypted, required String passphrase}) async {
    final Uint8List bytes = Uint8List.fromList(encrypted);

    if (bytes.length <= headerLengthBytes + tagLengthBytes) {
      throw const FormatException('E2E payload too short');
    }
    for (int i = 0; i < magicBytes.length; i++) {
      if (bytes[i] != magicBytes[i]) throw const FormatException('Not an Inkling E2E payload');
    }

    final List<int> salt = bytes.sublist(magicBytes.length, magicBytes.length + saltLengthBytes);
    final int nonceStart = magicBytes.length + saltLengthBytes;
    final List<int> nonce = bytes.sublist(nonceStart, nonceStart + nonceLengthBytes);
    final int tagStart = nonceStart + nonceLengthBytes;
    final List<int> mac = bytes.sublist(tagStart, tagStart + tagLengthBytes);
    final List<int> cipherText = bytes.sublist(tagStart + tagLengthBytes);

    final Uint8List key = await deriveKey(passphrase: passphrase, salt: salt);
    final SecretBox box = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));

    final List<int> plaintext = await _aesGcm.decrypt(box, secretKey: SecretKey(key));
    return Uint8List.fromList(plaintext);
  }
}
