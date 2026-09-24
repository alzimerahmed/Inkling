import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:storypad/core/objects/e2e_sync_config_object.dart';
import 'package:storypad/core/repositories/backup_repository.dart';
import 'package:storypad/core/services/backups/sync_steps/utils/backup_databases_to_backup_object_service.dart';
import 'package:storypad/core/services/gzip_service.dart';
import 'package:storypad/core/services/logger/app_logger.dart';
import 'package:storypad/core/services/sync/e2e_sync_service.dart';
import 'package:storypad/core/storages/e2e_sync_config_storage.dart';

/// ViewModel for the opt-in E2E-encrypted sync settings screen (Gap #12).
///
/// Manual-trigger only in v1: "Sync now" builds a standard backup artifact
/// (same payload as cloud backup), encrypts it client-side, and uploads it to
/// the user's WebDAV/Nextcloud server.
class SyncViewModel extends ChangeNotifier {
  SyncViewModel() {
    _load();
  }

  final E2eSyncService _syncService = E2eSyncService();
  final E2eSyncConfigStorage _storage = E2eSyncConfigStorage();

  final TextEditingController serverUrlController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController appPasswordController = TextEditingController();
  final TextEditingController passphraseController = TextEditingController();

  bool enabled = false;
  bool busy = false;
  String? lastSyncedAtIso;
  String? statusMessage;

  /// Number of changes restored by the last successful sync (for the
  /// "synced with changes" message), null when not applicable.
  int? lastSyncedChanges;

  bool get busySyncing => busy;

  Future<void> _load() async {
    final E2eSyncConfigObject? config = await _storage.readObject();
    if (config != null) {
      serverUrlController.text = config.serverUrl;
      usernameController.text = config.username;
      appPasswordController.text = config.appPassword;
      passphraseController.text = config.passphrase;
      enabled = config.enabled;
      lastSyncedAtIso = config.lastSyncedAtIso;
    }
    notifyListeners();
  }

  /// Persists the form. Returns false when required fields are missing or
  /// invalid (non-https URL, too-short passphrase).
  Future<bool> save() async {
    final String serverUrl = normalizeServerUrl(serverUrlController.text);
    final String username = usernameController.text.trim();
    final String passphrase = passphraseController.text;

    if (serverUrl.isEmpty || username.isEmpty || passphrase.isEmpty) return false;
    if (!isServerUrlSecure(serverUrl)) return false;
    if (!isPassphraseAcceptable(passphrase)) return false;

    final E2eSyncConfigObject? existing = await _storage.readObject();
    final E2eSyncConfigObject config =
        (existing ??
                E2eSyncConfigObject(
                  serverUrl: serverUrl,
                  username: username,
                  appPassword: appPasswordController.text,
                  passphrase: passphrase,
                ))
            .copyWith(
              serverUrl: serverUrl,
              username: username,
              appPassword: appPasswordController.text,
              passphrase: passphrase,
              enabled: enabled,
            );

    await _storage.writeObject(config);
    return true;
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    notifyListeners();

    // Persist in both directions: turning sync off must survive restarts
    // even when the form is incomplete (save() would bail on validation).
    if (value) {
      await save();
    } else {
      final E2eSyncConfigObject? existing = await _storage.readObject();
      if (existing != null) {
        await _storage.writeObject(existing.copyWith(enabled: false));
      }
    }
  }

  /// Manual "Sync now": build backup artifact → encrypt → upload → record
  /// last-sync time. Then pull the remote copy back down and merge it, so a
  /// single tap performs a full round-trip sync.
  Future<void> syncNow() async {
    if (busy) return;
    busy = true;
    statusMessage = null;
    lastSyncedChanges = null;
    notifyListeners();

    try {
      final bool saved = await save();
      if (!saved) {
        statusMessage = 'page.sync.error_missing_fields';
        return;
      }
      if (passphraseController.text.isEmpty) {
        statusMessage = 'page.sync.error_missing_fields';
        return;
      }

      final DateTime now = DateTime.now();
      final backup = await BackupDatabasesToBackupObjectService.call(
        databases: BackupRepository.databases,
        lastUpdatedAt: now,
        hasCompression: true,
      );
      final List<int> archiveBytes = GzipService.compress(
        jsonEncode(backup.toContents()),
      );

      final io.Directory tempDir = await io.Directory.systemTemp.createTemp(
        'inkling_e2e_sync',
      );
      final io.File tempFile = io.File(
        '${tempDir.path}/inkling-backup-${now.toIso8601String().replaceAll(':', '.')}.json.gz',
      );
      await tempFile.writeAsBytes(archiveBytes);

      try {
        final result = await _syncService.syncNow(
          backupFile: tempFile,
          passphrase: passphraseController.text,
        );
        if (!result.success) {
          AppLogger.d('E2eSyncService#syncNow upload failed: ${result.error}');
          statusMessage = 'page.sync.error_sync_failed';
          return;
        }

        final int changes = await _syncService.downloadDecryptAndRestore(
          passphrase: passphraseController.text,
        );
        lastSyncedAtIso = DateTime.now().toIso8601String();
        lastSyncedChanges = changes;
        statusMessage = changes > 0 ? 'page.sync.synced_with_changes' : 'page.sync.synced_up_to_date';
      } finally {
        try {
          if (tempFile.existsSync()) tempFile.deleteSync();
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    } catch (e, s) {
      AppLogger.error('SyncViewModel#syncNow failed: $e', stackTrace: s);
      statusMessage = 'page.sync.error_sync_failed';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Strips trailing slashes and surrounding whitespace from a server URL.
  static String normalizeServerUrl(String raw) => raw.trim().replaceAll(RegExp(r'/+$'), '');

  /// Only https is accepted: WebDAV uses Basic auth, so plaintext HTTP would
  /// send the app password (and, more importantly, the encrypted journal is
  /// still metadata-leaking) in the clear.
  static bool isServerUrlSecure(String url) {
    final Uri? uri = Uri.tryParse(url);
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http' && _isLocalLoopback(uri));
  }

  static bool _isLocalLoopback(Uri uri) {
    final String host = uri.host;
    return host == 'localhost' || host == '127.0.0.1' || host == '::1';
  }

  static bool isPassphraseAcceptable(String passphrase) => passphrase.length >= 8;

  @override
  void dispose() {
    serverUrlController.dispose();
    usernameController.dispose();
    appPasswordController.dispose();
    passphraseController.dispose();
    super.dispose();
  }
}
