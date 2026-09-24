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
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:storypad/providers/tags_provider.dart';
import 'package:storypad/widgets/base_view/base_route.dart';
import 'package:storypad/widgets/sp_icons.dart';

enum ExternalImportSource { dayOne, daylio, keep, evernote }

class ImportExternalRoute extends BaseRoute {
  const ImportExternalRoute({required this.source});

  final ExternalImportSource source;

  @override
  Widget buildPage(BuildContext context) => ImportExternalView(params: this);
}

class ImportExternalView extends StatelessWidget {
  const ImportExternalView({
    super.key,
    required this.params,
  });

  final ImportExternalRoute params;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ImportExternalViewModel>(
      create: (context) => ImportExternalViewModel(params: params),
      builder: (context, child) {
        return _ImportExternalContent(Provider.of(context));
      },
    );
  }
}

class ImportExternalViewModel extends ChangeNotifier with DisposeAwareMixin {
  final ImportExternalRoute params;

  ImportExternalViewModel({required this.params});

  /// Parsed entries awaiting confirmation (dry-run preview).
  List<ImportedStoryDraft>? drafts;
  int skippedCount = 0;
  Map<String, String> photoFiles = {};

  bool get hasPreview => drafts != null && drafts!.isNotEmpty;

  /// Parses the picked file(s) off the main isolate, then shows the dry-run
  /// preview. Nothing is written to the DB until [confirm] is called.
  Future<void> parse(BuildContext context) async {
    final source = params.source;

    // File picking uses platform channels — must happen on the main isolate.
    final List<String> paths = await _pickFiles(source);
    if (paths.isEmpty || !context.mounted) return;

    final result = await MessengerService.of(context).showLoading(
      debugSource: '$runtimeType#parse',
      future: () => Isolate.run(() => _parseInIsolate(source, paths)),
    );

    if (result == null) {
      drafts = null;
      notifyListeners();
      return;
    }

    if (result.drafts.isEmpty) {
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
        return (await AppFilePickerService.pickMultipleJsonFiles())
            .map((e) => e.path)
            .toList();
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
  ) async {
    switch (source) {
      case ExternalImportSource.dayOne:
        final bytes = await File(paths.first).readAsBytes();
        if (paths.first.toLowerCase().endsWith('.zip')) {
          final tempDir = Directory(
            '${SupportDirectoryPath.tmp.directoryPath}/day_one_import_${DateTime.now().millisecondsSinceEpoch}',
          );
          return DayOneImportParser.parseZip(
            zipBytes: bytes,
            tempPhotoDir: tempDir,
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
        mapMoodsToFeelingTags: params.source == ExternalImportSource.daylio,
      ),
    );

    final importedCount = result?.imported ?? 0;
    final photosImported = result?.photosImported ?? 0;
    final photosSkipped = result?.photosSkipped ?? 0;

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
}

class _ImportExternalContent extends StatelessWidget {
  const _ImportExternalContent(this.viewModel);

  final ImportExternalViewModel viewModel;

  String get _sourceTitleKey {
    switch (viewModel.params.source) {
      case ExternalImportSource.dayOne:
        return 'list_tile.import_day_one.title';
      case ExternalImportSource.daylio:
        return 'list_tile.import_daylio.title';
      case ExternalImportSource.keep:
        return 'list_tile.import_keep.title';
      case ExternalImportSource.evernote:
        return 'list_tile.import_evernote.title';
    }
  }

  @override
  Widget build(BuildContext context) {
    final drafts = viewModel.drafts;

    return Scaffold(
      appBar: AppBar(title: Text(tr(_sourceTitleKey))),
      body: _buildBody(context, drafts),
      bottomNavigationBar: _buildBottomBar(context, drafts),
    );
  }

  Widget _buildBody(BuildContext context, List<ImportedStoryDraft>? drafts) {
    if (drafts == null) {
      return _buildIntro(context);
    }
    if (drafts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            tr('snack_bar.empty_or_invalid_file'),
            textAlign: TextAlign.center,
            style: TextTheme.of(context).bodyLarge,
          ),
        ),
      );
    }
    return _buildPreviewList(context, drafts);
  }

  Widget _buildIntro(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            SpIcons.importOffline,
            size: 48.0,
            color: ColorScheme.of(context).primary,
          ),
          const SizedBox(height: 16.0),
          Text(
            tr('import_external.pick_file_hint'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24.0),
          FilledButton.icon(
            icon: const Icon(SpIcons.importOffline),
            label: Text(tr('button.select_file')),
            onPressed: () => viewModel.parse(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewList(
    BuildContext context,
    List<ImportedStoryDraft> drafts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
          child: Text(
            [
              plural('plural.entry', drafts.length),
              if (viewModel.skippedCount > 0) ...[
                ' · ',
                tr(
                  'import_external.skipped',
                  args: [viewModel.skippedCount.toString()],
                ),
              ],
            ].join(),
            style: TextTheme.of(context).titleSmall,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: drafts.length,
            itemBuilder: (context, index) {
              final draft = drafts[index];
              return ListTile(
                title: Text(
                  (draft.title?.trim().isNotEmpty == true)
                      ? draft.title!
                      : (draft.body?.split('\n').first ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    MaterialLocalizations.of(
                      context,
                    ).formatFullDate(draft.date),
                    if (draft.tags.isNotEmpty) draft.tags.join(', '),
                    if (draft.feeling != null) draft.feeling!,
                    if (draft.photoFileNames.isNotEmpty)
                      tr(
                        'import_external.photos',
                        args: [draft.photoFileNames.length.toString()],
                      ),
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    List<ImportedStoryDraft>? drafts,
  ) {
    if (drafts == null || drafts.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => viewModel.parse(context),
                child: Text(tr('button.select_file')),
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: FilledButton(
                onPressed: () => viewModel.confirm(context),
                child: Text(tr('button.import')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
