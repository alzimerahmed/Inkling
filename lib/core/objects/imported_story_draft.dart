/// A single parsed entry from an external journal app export (Day One,
/// Daylio, Google Keep, Evernote), before it is mapped onto Inkling's
/// [StoryDbModel].
///
/// Parsers are pure (no I/O, no DB) so they can run inside `Isolate.run`
/// and be unit-tested against text fixtures.
class ImportedStoryDraft {
  const ImportedStoryDraft({
    required this.date,
    this.title,
    this.body,
    this.tags = const [],
    this.feeling,
    this.photoFileNames = const [],
    this.warnings = const [],
  });

  /// Entry date (creation date in the source app). Never null — entries
  /// without a parsable date are dropped by the parser (counted as skipped).
  final DateTime date;

  /// Entry title, if the source format has one (Keep, Evernote). Day One and
  /// Daylio entries are body-only; the first line may be promoted to a title
  /// by the mapper.
  final String? title;

  /// Plain-text body (markdown-ish). Embedded images are NOT inlined here —
  /// photo references are carried in [photoFileNames] and resolved by the
  /// importer (Day One zip) or skipped with a warning.
  final String? body;

  /// Tag/label names as they appeared in the source app.
  final List<String> tags;

  /// Mood/feeling string (Day One `mood`, Daylio `mood_title`). Mapped onto
  /// the legacy `StoryDbModel.feeling` field.
  final String? feeling;

  /// Photo file names referenced by the entry (Day One `photos[].fileName`).
  /// The importer matches these against files found in a Day One zip export.
  final List<String> photoFileNames;

  /// Non-fatal notes shown in the dry-run preview (e.g. "image skipped").
  final List<String> warnings;

  bool get hasBody => body != null && body!.trim().isNotEmpty;
}

/// Result of parsing an external export file.
class ImportedParseResult {
  const ImportedParseResult({
    required this.drafts,
    this.skippedCount = 0,
    this.photoFiles = const {},
  });

  final List<ImportedStoryDraft> drafts;

  /// Entries dropped (unparsable date, empty body, …).
  final int skippedCount;

  /// Photo files available in the export (Day One zip `photos/` entries),
  /// keyed by file name (no directory). Values are temp-file paths written
  /// while parsing off the main isolate — the importer copies them into
  /// asset storage and embeds them into the story body.
  final Map<String, String> photoFiles;
}
