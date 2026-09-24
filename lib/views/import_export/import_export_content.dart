part of 'import_export_view.dart';

class _ImportExportContent extends StatelessWidget {
  const _ImportExportContent(this.viewModel);

  final ImportExportViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final onlyExport = viewModel.params.showExport == true && viewModel.params.showImport != true;
    final onlyImport = viewModel.params.showImport == true && viewModel.params.showExport != true;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          onlyExport
              ? tr('general.export')
              : onlyImport
              ? tr('general.import')
              : tr('page.import_export_backup'),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16.0),
          if (!onlyExport) ...[
            if (!onlyImport) SpSectionTitle(title: tr('general.import')),
            ListTile(
              leading: const Icon(SpIcons.importOffline),
              title: Text(tr('list_tile.import_storypad_json.title')),
              onTap: () => viewModel.import(context),
            ),
            ListTile(
              leading: const Icon(SpIcons.photo),
              title: Text(tr('list_tile.import_media.title')),
              onTap: () => viewModel.importMedia(context),
            ),
            ListTile(
              leading: const Icon(SpIcons.importOffline),
              title: Text(tr('list_tile.import_day_one.title')),
              onTap: () => const ImportExternalRoute(source: ExternalImportSource.dayOne).push(context),
            ),
            ListTile(
              leading: const Icon(SpIcons.importOffline),
              title: Text(tr('list_tile.import_daylio.title')),
              onTap: () => const ImportExternalRoute(source: ExternalImportSource.daylio).push(context),
            ),
            ListTile(
              leading: const Icon(SpIcons.importOffline),
              title: Text(tr('list_tile.import_keep.title')),
              onTap: () => const ImportExternalRoute(source: ExternalImportSource.keep).push(context),
            ),
            ListTile(
              leading: const Icon(SpIcons.importOffline),
              title: Text(tr('list_tile.import_evernote.title')),
              onTap: () => const ImportExternalRoute(source: ExternalImportSource.evernote).push(context),
            ),
          ],
          if (!onlyExport && !onlyImport) const Divider(),
          if (!onlyImport) _ExportSection(viewModel: viewModel),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 16.0),
        ],
      ),
    );
  }
}
