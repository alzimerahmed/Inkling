import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/sync/e2e_encryption_service.dart';

void main() {
  final E2eEncryptionService service = E2eEncryptionService();

  group('E2eEncryptionService', () {
    test('encrypt → decrypt round-trips the original bytes', () async {
      final original = Uint8List.fromList(utf8.encode('Inkling journal backup payload — ünïcode ✓'));

      final encrypted = await service.encrypt(plaintext: original, passphrase: 'correct horse battery staple');
      expect(encrypted, isNot(equals(original)));

      final decrypted = await service.decrypt(encrypted: encrypted, passphrase: 'correct horse battery staple');
      expect(decrypted, equals(original));
    });

    test('round-trips large binary payloads (backup-archive sized)', () async {
      final original = Uint8List.fromList(List<int>.generate(512 * 1024, (i) => i % 251));

      final encrypted = await service.encrypt(plaintext: original, passphrase: 'p@ss');
      final decrypted = await service.decrypt(encrypted: encrypted, passphrase: 'p@ss');

      expect(decrypted, equals(original));
    });

    test('key derivation is deterministic for the same passphrase and salt', () async {
      const List<int> salt = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];

      final key1 = await service.deriveKey(passphrase: 'same-passphrase', salt: salt);
      final key2 = await service.deriveKey(passphrase: 'same-passphrase', salt: salt);

      expect(key1, equals(key2));
      expect(key1.length, 32); // AES-256
    });

    test('key derivation differs for different passphrases and salts', () async {
      const List<int> salt = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];

      final keyA = await service.deriveKey(passphrase: 'alpha', salt: salt);
      final keyB = await service.deriveKey(passphrase: 'beta', salt: salt);
      final keyC = await service.deriveKey(passphrase: 'alpha', salt: [2, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]);

      expect(keyA, isNot(equals(keyB)));
      expect(keyA, isNot(equals(keyC)));
    });

    test('decryption fails with the wrong passphrase (GCM authentication)', () async {
      final original = utf8.encode('secret diary entry');
      final encrypted = await service.encrypt(plaintext: original, passphrase: 'right');

      expect(
        () => service.decrypt(encrypted: encrypted, passphrase: 'wrong'),
        throwsA(anything),
      );
    });

    test('tampered ciphertext is rejected', () async {
      final encrypted = await service.encrypt(plaintext: utf8.encode('secret'), passphrase: 'pw');
      final tampered = Uint8List.fromList(encrypted);
      tampered[tampered.length - 1] ^= 0xFF;

      expect(() => service.decrypt(encrypted: tampered, passphrase: 'pw'), throwsA(anything));
    });

    test('payload embeds magic header, salt, and nonce', () async {
      final salt = List<int>.generate(16, (i) => i);
      final nonce = List<int>.generate(12, (i) => 100 + i);

      final encrypted = await service.encrypt(
        plaintext: utf8.encode('x'),
        passphrase: 'pw',
        salt: salt,
        nonce: nonce,
      );

      expect(encrypted.sublist(0, E2eEncryptionService.magicBytes.length), equals(E2eEncryptionService.magicBytes));
      expect(encrypted.sublist(E2eEncryptionService.magicBytes.length, E2eEncryptionService.magicBytes.length + 16), equals(salt));
      expect(
        encrypted.sublist(E2eEncryptionService.magicBytes.length + 16, E2eEncryptionService.magicBytes.length + 28),
        equals(nonce),
      );
    });

    test('rejects malformed payloads', () async {
      expect(() => service.decrypt(encrypted: [1, 2, 3], passphrase: 'pw'), throwsA(isA<FormatException>()));
      expect(
        () => service.decrypt(encrypted: utf8.encode('not-an-e2e-payload-at-all-xxxxxxxx'), passphrase: 'pw'),
        throwsA(isA<FormatException>()),
      );
    });

    test('same plaintext + same passphrase encrypts differently (fresh nonce)', () async {
      final original = utf8.encode('identical');
      final a = await service.encrypt(plaintext: original, passphrase: 'pw');
      final b = await service.encrypt(plaintext: original, passphrase: 'pw');
      expect(a, isNot(equals(b)));
    });
  });
}
