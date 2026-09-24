import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/core/mixins/dispose_aware_mixin.dart';
import 'package:storypad/core/objects/imported_story_draft.dart';
import 'package:storypad/core/services/assets/app_file_picker_service.dart';
import 'package:storypad/core/services/import/day_one_import_parser.dart';
import 'package:storypad/core/services/import/daylio_import_parser.dart';
import 'package:storypad/core/services/import/evernote_enex_import_parser.dart';
import 'package:storypad/core/services/import/import_external_stories_service.dart';
import 'package:storypad/core/services/import/keep_import_parser.dart';
import 'package:storypad/core/services/messenger_service.dart';
import 'package:storypad/core/types/support_directory_path.dart';
import 'package:storypad/providers/tags_provider.dart';
import 'package:storypad/views/import_export/import_external/import_external_view.dart';

class ImportExternalViewModel extends ChangeNotifier with DisposeAwareMixin {
  final ImportExternalRoute params;

  ImportExternalViewModel({required this.params});

  /// Parsed entries awaiting confirmation (dry-run preview).
  List<ImportedStoryDraft>? drafts;
  int skippedCount = 0;
  Map<String, String> photoFiles = {};

  /// Temp directory holding photos extracted from a Day One zip. Deleted
  /// after a successful import, a new parse, or when the view model dies.
  Directory? tempPhotoDir;

  bool get hasPreview => drafts != null && drafts!.isNotEmpty;

  /// Parses the picked file(s) off the main isolate, then shows the dry-run
  /// preview. Nothing is written to the DB until [confirm] is called.
  Future<void> parse(BuildContext context) async {
    final source = params.source;

    // File picking uses platform channels — must happen on the main isolate.
    final List<String> paths = await _pickFiles(source);
    if (paths.isEmpty || !context.mounted) return;

    // Fresh temp dir per parse; the previous one (if any) is stale.
    await _cleanupTempDir();
    if (!context.mounted) return;
    tempPhotoDir = Directory(
      '${SupportDirectoryPath.tmp.directoryPath}/day_one_import_${DateTime.now().millisecondsSinceEpoch}',
    );
    final tempDir = tempPhotoDir!;

    Object? parseError;
    final result = await MessengerService.of(context).showLoading(
      debugSource: '$runtimeType#parse',
      future: () async {
        try {
          return await Isolate.run(
            () => _parseInIsolate(source, paths, tempDir),
          );
        } catch (e) {
          parseError = e;
          return null;
        }
      },
    );

    if (parseError != null || result == null) {
      await _cleanupTempDir();
      drafts = null;
      notifyListeners();
      if (context.mounted) {
        MessengerService.of(
          context,
        ).showSnackBar(tr('snack_bar.import_parse_failed'), success: false);
      }
      return;
    }

    if (result.drafts.isEmpty) {
      await _cleanupTempDir();
      drafts = [];
      skippedCount = result.skippedCount;
      notifyListeners();
      return;
    }

    drafts = result.drafts;
    skippedCount = result.skippedCount;
    photoFiles = result.photoFiles;
    notifyListeners();
  }

  /// File picking (platform channels) — main isolate only.
  Future<List<String>> _pickFiles(ExternalImportSource source) async {
    switch (source) {
      case ExternalImportSource.dayOne:
        final file = await AppFilePickerService.pickDayOneFile();
        return file == null ? [] : [file.path];
      case ExternalImportSource.daylio:
        final file = await AppFilePickerService.pickCsvFile();
        return file == null ? [] : [file.path];
      case ExternalImportSource.keep:
        return (await AppFilePickerService.pickMultipleJsonFiles()).map((e) => e.path).toList();
      case ExternalImportSource.evernote:
        final file = await AppFilePickerService.pickEnexFile();
        return file == null ? [] : [file.path];
    }
  }

  /// Runs in a background isolate — file I/O + parsing only, no DB access
  /// (ObjectBox stores are per-isolate).
  static Future<ImportedParseResult?> _parseInIsolate(
    ExternalImportSource source,
    List<String> paths,
    Directory tempPhotoDir,
  ) async {
    switch (source) {
      case ExternalImportSource.dayOne:
        final bytes = await File(paths.first).readAsBytes();
        if (paths.first.toLowerCase().endsWith('.zip')) {
          return DayOneImportParser.parseZip(
            zipBytes: bytes,
            tempPhotoDir: tempPhotoDir,
          );
        }
        return DayOneImportParser.parseJson(utf8.decode(bytes));
      case ExternalImportSource.daylio:
        return DaylioImportParser.parse(await File(paths.first).readAsString());
      case ExternalImportSource.keep:
        final drafts = <ImportedStoryDraft>[];
        int skipped = 0;
        for (final path in paths) {
          final draft = KeepImportParser.parse(await File(path).readAsString());
          if (draft == null) {
            skipped++;
          } else {
            drafts.add(draft);
          }
        }
        return ImportedParseResult(drafts: drafts, skippedCount: skipped);
      case ExternalImportSource.evernote:
        return EvernoteEnexImportParser.parse(
          await File(paths.first).readAsString(),
        );
    }
  }

  /// Confirms the preview and writes stories/tags/photos into the DB.
  Future<void> confirm(BuildContext context) async {
    final currentDrafts = drafts;
    if (currentDrafts == null || currentDrafts.isEmpty) return;

    final result = await MessengerService.of(context).showLoading(
      debugSource: '$runtimeType#confirm',
      future: () => ImportExternalStoriesService.call(
        drafts: currentDrafts,
        photoFiles: photoFiles,
        mapMoodToFeelingTag: params.source == ExternalImportSource.daylio,
      ),
    );

    final importedCount = result?.imported ?? 0;
    final photosImported = result?.photosImported ?? 0;
    final photosSkipped = result?.photosSkipped ?? 0;

    // Photos are copied into asset storage during the import — the temp
    // extraction dir is no longer needed.
    await _cleanupTempDir();

    // Refresh tag chips everywhere (home sidebar, search, editor).
    if (context.mounted) context.read<TagsProvider>().reload();

    drafts = null;
    photoFiles = {};
    notifyListeners();

    if (!context.mounted) return;
    MessengerService.of(context).showSnackBar(
      tr(
        'snack_bar.import_external_done',
        args: [
          importedCount.toString(),
          photosImported.toString(),
          photosSkipped.toString(),
        ],
      ),
    );
    Navigator.of(context).maybePop(importedCount);
  }

  Future<void> _cleanupTempDir() async {
    final dir = tempPhotoDir;
    tempPhotoDir = null;
    if (dir != null && await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {
        // Best-effort cleanup — leftover temp files are harmless.
      }
    }
  }

  @override
  void dispose() {
    _cleanupTempDir();
    super.dispose();
  }
}
