import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/core/objects/imported_story_draft.dart';

import 'package:storypad/views/import_export/import_external/import_external_view_model.dart';
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
  const ImportExternalView({super.key, required this.params});

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
                  (draft.title?.trim().isNotEmpty == true) ? draft.title! : (draft.body?.split('\n').first ?? ''),
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
                    if (draft.warnings.isNotEmpty)
                      draft.warnings
                          .map(
                            (w) => w == 'attachments_skipped' ? tr('import_external.warning_attachments_skipped') : w,
                          )
                          .join(', '),
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
