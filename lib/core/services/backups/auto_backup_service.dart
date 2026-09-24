import 'dart:convert';
import 'dart:io';

import 'package:storypad/core/repositories/backup_repository.dart';
import 'package:storypad/core/services/backups/sync_steps/utils/backup_databases_to_backup_object_service.dart';
import 'package:storypad/core/services/gzip_service.dart';
import 'package:storypad/core/services/logger/app_logger.dart';
import 'package:storypad/core/storages/auto_backup_storage.dart';
import 'package:storypad/core/types/support_directory_path.dart';

/// Scheduled local auto-backup: periodically writes a full, self-contained
/// backup JSON (same payload format as manual export / cloud upload) into the
/// app's support directory, with a retention policy.
///
/// Runs opportunistically when the user navigates home (see
/// `RootViewModel.autoBackupWhenNavigateToHome`) — no background-scheduler
/// plugin needed, which keeps the community flavor FOSS/F-Droid-clean.
/// The JSON encode step already runs off the main isolate via `compute`
/// inside [BackupDatabasesToBackupObjectService].
class AutoBackupService {
  static const List<int> intervalOptionsInHours = [6, 12, 24, 24 * 7];
  static const int defaultKeepCount = 5;

  static final AutoBackupEnabledStorage _enabledStorage = AutoBackupEnabledStorage();
  static final AutoBackupIntervalStorage _intervalStorage = AutoBackupIntervalStorage();
  static final AutoBackupKeepCountStorage _keepCountStorage = AutoBackupKeepCountStorage();
  static final AutoBackupLastRunStorage _lastRunStorage = AutoBackupLastRunStorage();

  /// True when a backup was taken this call.
  static Future<bool> maybeRun() async {
    final bool enabled = await _enabledStorage.read() ?? false;
    if (!enabled) return false;

    final int intervalHours = await _intervalStorage.read() ?? intervalOptionsInHours.first;
    final String? lastRunAt = await _lastRunStorage.read();

    final DateTime now = DateTime.now();
    final DateTime? lastRun = lastRunAt == null ? null : DateTime.tryParse(lastRunAt)?.toLocal();

    if (!isDue(lastRun, now, intervalHours)) return false;

    try {
      await _writeBackup(now);
      await _lastRunStorage.write(now.toIso8601String());
      return true;
    } catch (e) {
      AppLogger.d('AutoBackupService#maybeRun failed: $e');
      return false;
    }
  }

  static Future<void> _writeBackup(DateTime now) async {
    final backup = await BackupDatabasesToBackupObjectService.call(
      databases: BackupRepository.databases,
      lastUpdatedAt: now,
      hasCompression: true,
    );

    final Directory dir = Directory(
      '${SupportDirectoryPath.backups.directoryPath}/auto_backup',
    );
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final String encoded = jsonEncode(backup.toContents());
    final List<int> bytes = GzipService.compress(encoded);

    final String fileName = 'auto-backup-${now.toIso8601String().replaceAll(':', '.')}.json.gz';
    await File('${dir.path}/$fileName').writeAsBytes(bytes);

    await applyRetention(
      directory: dir,
      keep: await _keepCountStorage.read() ?? defaultKeepCount,
    );
  }

  /// Whether an auto-backup is due. Pure — unit-tested.
  static bool isDue(DateTime? lastRun, DateTime now, int intervalHours) {
    if (intervalHours <= 0) return false;
    if (lastRun == null) return true;
    return now.difference(lastRun).inMinutes >= intervalHours * 60;
  }

  /// Deletes oldest files in [directory] so only the newest [keep] remain.
  /// Returns the number of deleted files. Pure w.r.t. the file list —
  /// unit-tested via [prune].
  static Future<int> applyRetention({
    required Directory directory,
    required int keep,
  }) async {
    if (keep < 0) return 0;

    final List<File> files = directory.listSync().whereType<File>().toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    int deleted = 0;
    for (final File file in files.skip(keep)) {
      try {
        await file.delete();
        deleted++;
      } catch (_) {
        // Best-effort retention; a locked file must not fail the backup.
      }
    }
    return deleted;
  }
}
