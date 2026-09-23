import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/backups/auto_backup_service.dart';

void main() {
  group('AutoBackupService.isDue', () {
    final DateTime now = DateTime(2026, 9, 23, 12);

    test('null lastRun is always due', () {
      expect(AutoBackupService.isDue(null, now, 24), isTrue);
    });

    test('not due inside the interval', () {
      final lastRun = now.subtract(const Duration(hours: 23));
      expect(AutoBackupService.isDue(lastRun, now, 24), isFalse);
    });

    test('due exactly at the interval boundary', () {
      final lastRun = now.subtract(const Duration(hours: 24));
      expect(AutoBackupService.isDue(lastRun, now, 24), isTrue);
    });

    test('due past the interval', () {
      final lastRun = now.subtract(const Duration(days: 8));
      expect(AutoBackupService.isDue(lastRun, now, 24 * 7), isTrue);
    });

    test('non-positive interval is never due', () {
      expect(AutoBackupService.isDue(null, now, 0), isFalse);
      expect(AutoBackupService.isDue(null, now, -1), isFalse);
    });
  });

  group('AutoBackupService.applyRetention', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('auto_backup_test');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    Future<File> createFile(String name, {DateTime? modified}) async {
      final file = File('${tempDir.path}/$name');
      await file.writeAsString('x');
      if (modified != null) await file.setLastModified(modified);
      return file;
    }

    test('keeps the newest N files, deletes older ones', () async {
      await createFile('old1', modified: DateTime(2026, 1, 1));
      await createFile('old2', modified: DateTime(2026, 2, 1));
      await createFile('new1', modified: DateTime(2026, 3, 1));
      await createFile('new2', modified: DateTime(2026, 4, 1));
      await createFile('new3', modified: DateTime(2026, 5, 1));

      final deleted = await AutoBackupService.applyRetention(
        directory: tempDir,
        keep: 2,
      );

      expect(deleted, 3);
      final remaining =
          tempDir.listSync().whereType<File>().map((f) => f.uri.pathSegments.last).toList()
            ..sort();
      expect(remaining, ['new2', 'new3']);
    });

    test('keeps everything when under the limit', () async {
      await createFile('a', modified: DateTime(2026, 1, 1));
      await createFile('b', modified: DateTime(2026, 2, 1));

      final deleted = await AutoBackupService.applyRetention(
        directory: tempDir,
        keep: 5,
      );

      expect(deleted, 0);
      expect(tempDir.listSync().whereType<File>().length, 2);
    });

    test('keep=0 wipes the directory', () async {
      await createFile('a');
      final deleted = await AutoBackupService.applyRetention(
        directory: tempDir,
        keep: 0,
      );
      expect(deleted, 1);
      expect(tempDir.listSync().whereType<File>(), isEmpty);
    });
  });
}
