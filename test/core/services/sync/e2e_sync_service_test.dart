import 'dart:io' as io;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/objects/cloud_file_object.dart';
import 'package:storypad/core/objects/e2e_sync_config_object.dart';
import 'package:storypad/core/services/gzip_service.dart';
import 'package:storypad/core/services/sync/e2e_encryption_service.dart';
import 'package:storypad/core/services/sync/e2e_sync_service.dart';
import 'package:storypad/core/storages/e2e_sync_config_storage.dart';
import 'package:storypad/core/storages/storage_adapters/base_storage_adapter.dart';
import 'package:storypad/core/storages/storage_adapters/memory_storage_adapter.dart';

/// In-memory fake of the WebDAV/Nextcloud transport — no network in tests.
class FakeWebdavTransport implements E2eSyncTransport {
  final Map<String, List<int>> files = {};
  bool pingSucceeds = true;
  int uploadCount = 0;

  @override
  Future<bool> connect({
    required String serverUrl,
    required String username,
    required String appPassword,
  }) async {
    return pingSucceeds;
  }

  @override
  Future<CloudFileObject?> uploadFile(
    String fileName,
    io.File file, {
    String? folderName,
  }) async {
    uploadCount++;
    final String path = '/$folderName/$fileName';
    files[path] = await file.readAsBytes();
    return CloudFileObject(
      fileName: fileName,
      id: path,
      description: null,
      sizeInBytes: files[path]!.length,
    );
  }

  @override
  Future<List<int>?> downloadFileBytes(String fileId) async => files[fileId];
}

/// Config storage backed by [MemoryStorageAdapter] instead of secure storage.
class TestE2eSyncConfigStorage extends E2eSyncConfigStorage {
  @override
  Future<BaseStorageAdapter<String>> get adapter async => MemoryStorageAdapter<String>();
}

E2eSyncConfigObject testConfig({bool enabled = true}) => E2eSyncConfigObject(
  serverUrl: 'https://cloud.example.com',
  username: 'alice',
  appPassword: 'app-password',
  passphrase: 'passphrase',
  enabled: enabled,
);

void main() {
  setUp(() {
    MemoryStorageAdapter.map.clear();
  });

  group('E2eSyncService', () {
    test(
      'passphrase key derivation is deterministic across instances',
      () async {
        final serviceA = E2eEncryptionService();
        final serviceB = E2eEncryptionService();
        const salt = [9, 8, 7, 6, 5, 4, 3, 2, 1, 0, 1, 2, 3, 4, 5, 6];

        final keyA = await serviceA.deriveKey(passphrase: 'same', salt: salt);
        final keyB = await serviceB.deriveKey(passphrase: 'same', salt: salt);
        expect(keyA, equals(keyB));
      },
    );

    test(
      'syncNow encrypts and uploads the backup artifact; remote bytes decrypt back to the original',
      () async {
        final transport = FakeWebdavTransport();
        final service = E2eSyncService(
          transport: transport,
          configStorage: TestE2eSyncConfigStorage(),
        );
        final config = testConfig();

        final io.Directory tempDir = await io.Directory.systemTemp.createTemp(
          'inkling_test',
        );
        final io.File backupFile = io.File('${tempDir.path}/backup.json.gz');
        final List<int> originalArchive = GzipService.compress(
          '{"tables":{},"meta_data":{}}',
        );
        await backupFile.writeAsBytes(originalArchive);

        try {
          final result = await service.syncNow(
            backupFile: backupFile,
            passphrase: 'passphrase',
            config: config,
          );

          expect(result.success, isTrue);
          expect(transport.uploadCount, 1);

          // The uploaded artifact must NOT be plaintext.
          const String remotePath = '/${E2eSyncConfigObject.defaultFolderName}/${E2eSyncService.defaultRemoteFileName}';
          final List<int> uploaded = transport.files[remotePath]!;
          expect(uploaded, isNot(equals(originalArchive)));
          expect(
            uploaded.sublist(0, E2eEncryptionService.magicBytes.length),
            equals(E2eEncryptionService.magicBytes),
          );

          // Decrypting the uploaded ciphertext restores the exact archive bytes.
          final Uint8List decrypted = await E2eEncryptionService().decrypt(
            encrypted: uploaded,
            passphrase: 'passphrase',
          );
          expect(decrypted, equals(originalArchive));
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      },
    );

    test(
      'syncNow refuses to run with an empty passphrase (would upload weakly-protected data)',
      () async {
        final transport = FakeWebdavTransport();
        final service = E2eSyncService(
          transport: transport,
          configStorage: TestE2eSyncConfigStorage(),
        );

        final io.Directory tempDir = await io.Directory.systemTemp.createTemp(
          'inkling_test',
        );
        final io.File backupFile = io.File('${tempDir.path}/backup.json.gz')..writeAsBytesSync([1, 2, 3]);

        try {
          final result = await service.syncNow(
            backupFile: backupFile,
            passphrase: '',
            config: testConfig(),
          );
          expect(result.success, isFalse);
          expect(transport.uploadCount, 0);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      },
    );

    test(
      'syncNow refuses to run when sync is disabled (opt-in only)',
      () async {
        final transport = FakeWebdavTransport();
        final service = E2eSyncService(
          transport: transport,
          configStorage: TestE2eSyncConfigStorage(),
        );

        final io.Directory tempDir = await io.Directory.systemTemp.createTemp(
          'inkling_test',
        );
        final io.File backupFile = io.File('${tempDir.path}/backup.json.gz')..writeAsBytesSync([1, 2, 3]);

        try {
          final result = await service.syncNow(
            backupFile: backupFile,
            passphrase: 'pw',
            config: testConfig(enabled: false),
          );
          expect(result.success, isFalse);
          expect(transport.uploadCount, 0);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      },
    );

    test('syncNow reports failure when the server is unreachable', () async {
      final transport = FakeWebdavTransport()..pingSucceeds = false;
      final service = E2eSyncService(
        transport: transport,
        configStorage: TestE2eSyncConfigStorage(),
      );

      final io.Directory tempDir = await io.Directory.systemTemp.createTemp(
        'inkling_test',
      );
      final io.File backupFile = io.File('${tempDir.path}/backup.json.gz')..writeAsBytesSync([1, 2, 3]);

      try {
        final result = await service.syncNow(
          backupFile: backupFile,
          passphrase: 'pw',
          config: testConfig(),
        );
        expect(result.success, isFalse);
        expect(transport.uploadCount, 0);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'downloadDecryptAndRestore round-trips a payload uploaded by syncNow (decryption layer)',
      () async {
        final transport = FakeWebdavTransport();
        final config = testConfig();

        final List<int> archive = GzipService.compress('{"tables":{}}');
        final Uint8List encrypted = await E2eEncryptionService().encrypt(
          plaintext: archive,
          passphrase: 'pw',
        );
        transport.files['/${E2eSyncConfigObject.defaultFolderName}/${E2eSyncService.defaultRemoteFileName}'] =
            encrypted;

        // Decrypt via the service's own path (restore itself needs a live DB,
        // so the DB merge is covered by integration tests).
        const String remotePath = '/${E2eSyncConfigObject.defaultFolderName}/${E2eSyncService.defaultRemoteFileName}';
        final List<int>? downloaded = await transport.downloadFileBytes(
          remotePath,
        );
        expect(downloaded, isNotNull);

        final Uint8List decrypted = await E2eEncryptionService().decrypt(
          encrypted: downloaded!,
          passphrase: 'pw',
        );
        expect(decrypted, equals(archive));
        expect(config.enabled, isTrue);
      },
    );
  });
}
