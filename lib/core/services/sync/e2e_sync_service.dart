import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:storypad/core/objects/backup_object.dart';
import 'package:storypad/core/objects/cloud_file_object.dart';
import 'package:storypad/core/objects/e2e_sync_config_object.dart';
import 'package:storypad/core/services/backups/sync_steps/utils/restore_backup_service.dart';
import 'package:storypad/core/services/backups/nextcloud_cloud_service.dart';
import 'package:storypad/core/services/gzip_service.dart';
import 'package:storypad/core/services/sync/e2e_encryption_service.dart';
import 'package:storypad/core/storages/e2e_sync_config_storage.dart';

/// Minimal transport contract a cloud backend must satisfy for E2E sync.
/// [NextcloudCloudService] satisfies this out of the box (its `connect` has an
/// extra optional `folderName` parameter, which is allowed); tests inject an
/// in-memory fake so no network is touched.
abstract interface class E2eSyncTransport {
  Future<bool> connect({
    required String serverUrl,
    required String username,
    required String appPassword,
  });

  Future<CloudFileObject?> uploadFile(
    String fileName,
    io.File file, {
    String? folderName,
  });

  Future<List<int>?> downloadFileBytes(String fileId);
}

/// Result of a manual "Sync now" run.
class E2eSyncResult {
  final bool success;
  final String? remoteFileId;
  final Object? error;

  const E2eSyncResult({required this.success, this.remoteFileId, this.error});
}

/// Opt-in, E2E-encrypted sync of the existing backup payload over WebDAV.
///
/// Reuses the app's standard backup artifact (gzip-compressed backup JSON —
/// the same bytes cloud backup uploads) rather than inventing a new schema:
/// the archive is encrypted client-side with [E2eEncryptionService] and the
/// ciphertext is uploaded as a single opaque file. The server never sees
/// plaintext or the passphrase.
///
/// v1 is manual-trigger only ("Sync now"); no background scheduling.
class E2eSyncService {
  E2eSyncService({
    E2eSyncTransport? transport,
    E2eEncryptionService? encryptionService,
    E2eSyncConfigStorage? configStorage,
  }) : _transport = transport ?? _DefaultTransport(),
       _encryption = encryptionService ?? E2eEncryptionService(),
       _storage = configStorage ?? E2eSyncConfigStorage();

  final E2eSyncTransport _transport;
  final E2eEncryptionService _encryption;
  final E2eSyncConfigStorage _storage;

  static const String defaultRemoteFileName = 'inkling-e2e-backup.json.gz.enc';

  Future<E2eSyncConfigObject?> readConfig() => _storage.readObject();

  Future<void> writeConfig(E2eSyncConfigObject config) =>
      _storage.writeObject(config);

  DateTime? lastSyncedAt(E2eSyncConfigObject? config) => config?.lastSyncedAt;

  /// Encrypts [backupFile] (a standard backup artifact — gzip JSON, same
  /// format cloud backup uploads) and uploads the ciphertext to WebDAV.
  /// Updates the last-sync timestamp on success.
  ///
  /// Hard-fails on an empty [passphrase]: encrypting with one would produce a
  /// remote blob that is trivially decryptable by anyone holding the file.
  Future<E2eSyncResult> syncNow({
    required io.File backupFile,
    required String passphrase,
    E2eSyncConfigObject? config,
  }) async {
    final E2eSyncConfigObject? effectiveConfig =
        config ?? await _storage.readObject();
    if (effectiveConfig == null || !effectiveConfig.enabled) {
      return E2eSyncResult(
        success: false,
        error: StateError('E2E sync is not enabled'),
      );
    }
    if (passphrase.isEmpty) {
      return E2eSyncResult(
        success: false,
        error: StateError('Passphrase is required for E2E sync'),
      );
    }

    io.Directory? tempDir;
    try {
      final bool connected = await _transport.connect(
        serverUrl: effectiveConfig.serverUrl,
        username: effectiveConfig.username,
        appPassword: effectiveConfig.appPassword,
      );
      if (!connected) throw StateError('Could not connect to the sync server');

      final List<int> archiveBytes = await backupFile.readAsBytes();
      final Uint8List encrypted = await _encryption.encrypt(
        plaintext: archiveBytes,
        passphrase: passphrase,
      );

      tempDir = await io.Directory.systemTemp.createTemp('inkling_e2e_sync');
      final io.File tempFile = io.File(
        '${tempDir.path}/$defaultRemoteFileName',
      );
      await tempFile.writeAsBytes(encrypted);

      final CloudFileObject? uploaded = await _transport.uploadFile(
        defaultRemoteFileName,
        tempFile,
        folderName:
            effectiveConfig.folderName ?? E2eSyncConfigObject.defaultFolderName,
      );
      if (uploaded == null)
        throw StateError('Upload failed: no file object returned');

      await _storage.writeObject(
        effectiveConfig.copyWith(
          lastSyncedAtIso: DateTime.now().toIso8601String(),
        ),
      );
      return E2eSyncResult(success: true, remoteFileId: uploaded.id);
    } catch (e) {
      return E2eSyncResult(success: false, error: e);
    } finally {
      try {
        tempDir?.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  /// Downloads the remote encrypted payload, decrypts it with [passphrase],
  /// and restores it into the local database (only-new-data merge via
  /// [RestoreBackupService]). Returns the number of restored changes.
  Future<int> downloadDecryptAndRestore({
    required String passphrase,
    E2eSyncConfigObject? config,
  }) async {
    final E2eSyncConfigObject? effectiveConfig =
        config ?? await _storage.readObject();
    if (effectiveConfig == null || !effectiveConfig.enabled) {
      throw StateError('E2E sync is not enabled');
    }

    final String remotePath =
        '${effectiveConfig.folderName ?? E2eSyncConfigObject.defaultFolderName}/$defaultRemoteFileName';
    final List<int>? encrypted = await _transport.downloadFileBytes(remotePath);
    if (encrypted == null)
      throw StateError('No remote sync payload found at $remotePath');

    final Uint8List archiveBytes = await _encryption.decrypt(
      encrypted: encrypted,
      passphrase: passphrase,
    );
    final String json = GzipService.decompressToString(archiveBytes);
    final BackupObject backup = BackupObject.fromContents(
      jsonDecode(json) as Map<String, dynamic>,
    );

    final RestoreBackupService restoreService = RestoreBackupService();
    return restoreService.restoreOnlyNewData(backup: backup);
  }
}

/// Default production transport: the existing WebDAV/Nextcloud backup service
/// (same credentials + remote paths the cloud-backup feature uses).
class _DefaultTransport implements E2eSyncTransport {
  final NextcloudCloudService _nextcloud = NextcloudCloudService();

  @override
  Future<bool> connect({
    required String serverUrl,
    required String username,
    required String appPassword,
  }) {
    return _nextcloud.connect(
      serverUrl: serverUrl,
      username: username,
      appPassword: appPassword,
    );
  }

  @override
  Future<List<int>?> downloadFileBytes(String fileId) =>
      _nextcloud.downloadFileBytes(fileId);

  @override
  Future<CloudFileObject?> uploadFile(
    String fileName,
    io.File file, {
    String? folderName,
  }) => _nextcloud.uploadFile(fileName, file, folderName: folderName);
}
