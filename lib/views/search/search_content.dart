part of 'search_view.dart';

class _SearchContent extends StatelessWidget {
  const _SearchContent(this.viewModel);

  final SearchViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return SpStoryListMultiEditWrapper.withListener(
      builder: (context, state) {
        return PopScope(
          canPop: !state.editing,
          onPopInvokedWithResult: (didPop, result) =>
              viewModel.onPopInvokedWithResult(didPop, result, context),
          child: buildScaffold(context, state),
        );
      },
    );
  }

  Widget buildScaffold(
    BuildContext context,
    SpStoryListMultiEditWrapperState state,
  ) {
    var visibleTags =
        viewModel.tags?.where((tag) {
          if (tag.id == 0) return true;
          if (tag.storiesCount == null) return false;
          return tag.storiesCount! > 0;
        }).toList() ??
        [];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !CupertinoSheetRoute.hasParentSheet(context),
        title: TextField(
          controller: viewModel.queryController,
          textInputAction: TextInputAction.search,
          style: Theme.of(context).appBarTheme.titleTextStyle,
          keyboardType: TextInputType.text,
          autofocus: false,
          decoration: InputDecoration(
            hintText: tr("input.story_search.hint"),
            border: InputBorder.none,
          ),
          onChanged: (value) => viewModel.searchText(value),
          onSubmitted: (value) => viewModel.searchText(value),
        ),
        actions: [
          Visibility(
            visible: viewModel.hasQuery,
            child: IconButton(
              tooltip: tr("button.clear"),
              icon: const Icon(SpIcons.backspace),
              onPressed: () => viewModel.clearQuery(context),
            ),
          ),
          IconButton(
            tooltip: tr("page.search_filter.title"),
            icon: viewModel.hasHiddenTagFilters
                ? Badge(
                    backgroundColor: ColorScheme.of(context).primary,
                    child: const Icon(SpIcons.tune),
                  )
                : const Icon(SpIcons.tune),
            onPressed: () => viewModel.goToFilterPage(context),
          ),
          if (CupertinoSheetRoute.hasParentSheet(context))
            CloseButton(onPressed: () => CupertinoSheetRoute.popSheet(context)),
        ],
        bottom: visibleTags.isNotEmpty == true && viewModel.showTagFilterBar
            ? PreferredSize(
                preferredSize: const Size.fromHeight(34.0 + 12.0),
                child: Column(
                  crossAxisAlignment: .start,
                  mainAxisAlignment: .start,
                  children: [
                    SizedBox(
                      width: .infinity,
                      child: SpScrollableChoiceChips<TagDbModel>(
                        key: viewModel.tagsChipsKey,
                        choices: visibleTags,
                        storiesCount: (TagDbModel tag) => tag.storiesCount,
                        toLabel: (TagDbModel tag) => tag.title,
                        selected: (TagDbModel tag) =>
                            viewModel.tagSelected(tag),
                        onToggle: (TagDbModel tag) =>
                            viewModel.toggleTag(tag, context),
                      ),
                    ),
                    const SizedBox(height: 12.0),
                  ],
                ),
              )
            : viewModel.hasQuery
            ? PreferredSize(
                preferredSize: const Size.fromHeight(34.0 + 12.0),
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    SizedBox(
                      width: .infinity,
                      child: _buildPresetChips(context),
                    ),
                    const SizedBox(height: 12.0),
                  ],
                ),
              )
            : null,
      ),
      bottomNavigationBar: buildBottomNavigationBar(context, state),
      body: buildBody(),
    );
  }

  Widget buildBody() {
    if (viewModel.searchFilter == null)
      return const Center(child: CircularProgressIndicator.adaptive());
    return SpStoryList.withQuery(
      filter: viewModel.searchFilter,
    );
  }

  /// One-tap filter presets shown while a query is active (Phase 4, gap #14).
  Widget _buildPresetChips(BuildContext context) {
    Widget presetChip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Row(
        children: [
          presetChip(
            label: tr('search.preset.starred'),
            selected: viewModel.presetStarredActive,
            onTap: viewModel.togglePresetStarred,
          ),
          presetChip(
            label: tr('search.preset.pinned'),
            selected: viewModel.presetPinnedActive,
            onTap: viewModel.togglePresetPinned,
          ),
          presetChip(
            label: tr('search.preset.this_year'),
            selected: viewModel.presetThisYearActive,
            onTap: viewModel.togglePresetThisYear,
          ),
        ],
      ),
    );
  }

  Widget buildBottomNavigationBar(
    BuildContext context,
    SpStoryListMultiEditWrapperState state,
  ) {
    return SpMultiEditBottomNavBar(
      editing: state.editing,
      onCancel: () => state.turnOffEditing(),
      buttons: [
        OutlinedButton(
          child: Text(
            "${tr("button.archive")} (${state.selectedStories.length})",
          ),
          onPressed: () => state.archiveAll(context),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: ColorScheme.of(context).error,
          ),
          child: Text(
            "${tr("button.move_to_bin")} (${state.selectedStories.length})",
          ),
          onPressed: () => state.moveToBinAll(context),
        ),
      ],
    );
  }
}
