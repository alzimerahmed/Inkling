part of 'story_pages_builder.dart';

class _TitleField extends StatelessWidget {
  const _TitleField({
    required this.titleFocusNode,
    required this.titleController,
    required this.preferences,
    required this.readOnly,
    required this.onChanged,
    required this.bodyFocusNode,
    required this.largerTitle,
  });

  final FocusNode titleFocusNode;
  final FocusNode bodyFocusNode;
  final bool largerTitle;
  final TextEditingController? titleController;
  final StoryPreferencesDbModel? preferences;
  final bool readOnly;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    double? fontSize =
        preferences?.titleFontSize ??
        Theme.of(context).textTheme.titleMedium?.fontSize;
    if (fontSize != null && largerTitle) fontSize += 2;

    TextStyle baseStyle = GoogleFonts.getFont(
      preferences?.titleFontFamily ??
          preferences?.fontFamily ??
          context.read<DevicePreferencesProvider>().preferences.fontFamily,
      color: Theme.of(context).textTheme.titleMedium?.color,
      fontSize: fontSize,
      fontWeight: AppTheme.getThemeFontWeight(
        context,
        preferences?.titleFontWeight ?? kTitleDefaultFontWeight,
      ),
    );

    return TextFormField(
      onChanged: readOnly ? null : onChanged,
      focusNode: titleFocusNode,
      readOnly: readOnly,
      controller: titleController,
      style: baseStyle,
      scrollPadding: EdgeInsets.zero,
      maxLines: null,
      maxLength: null,
      autofocus: false,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (value) => bodyFocusNode.requestFocus(),
      decoration: InputDecoration(
        hintText: tr('input.title.hint'),
        isCollapsed: true,
        contentPadding: const EdgeInsets.only(
          top: 12,
          left: 12.0,
          bottom: 4,
          right: 12.0,
        ),
        border: InputBorder.none,
      ),
    );
  }
}

/// Gap #18 "AI features (on-device only)" v1 (ADR-012): offers a title
/// derived from the body's first line via pure-Dart heuristics. Shown only
/// while editing, only when the title is still empty, and only when the user
/// opted in via Settings. No model, no network — the suggestion is computed
/// from the body plain text on every body change (cheap string ops).
class _SmartTitleSuggestionRow extends StatelessWidget {
  const _SmartTitleSuggestionRow({required this.page, required this.onApply});

  final StoryPageObject page;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final bool enabled = context
        .watch<DevicePreferencesProvider>()
        .enableSmartTitleSuggestion;
    if (!enabled) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: Listenable.merge([page.bodyController, page.titleController]),
      builder: (context, _) {
        final String? suggestion = SmartTitleSuggestionService.suggest(
          bodyPlainText: page.bodyController.document.toPlainText(),
          currentTitle: page.titleController.text,
        );
        if (suggestion == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 4.0, left: 12.0, right: 12.0),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ActionChip(
              avatar: const Icon(SpIcons.edit, size: 16.0),
              label: Text(
                suggestion,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              tooltip: tr('input.title.smart_suggestion.apply'),
              onPressed: () {
                page.titleController.text = suggestion;
                onApply();
              },
            ),
          ),
        );
      },
    );
  }
}
