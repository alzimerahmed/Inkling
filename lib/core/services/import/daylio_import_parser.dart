import 'package:csv/csv.dart';
import 'package:storypad/core/objects/imported_story_draft.dart';

/// Parses a Daylio CSV export into [ImportedStoryDraft]s.
///
/// Daylio CSV header (v1.7+):
/// `full_date,date_time,mood_title,mood_emoji,activities,note_title,note`
///
/// Mapping:
/// - `date_time` (or `full_date` fallback) → entry date
/// - `mood_title` → feeling
/// - `activities` (comma-separated) → tags
/// - `note_title` + `note` → body (title promoted by the mapper)
class DaylioImportParser {
  static ImportedParseResult parse(String content) {
    final drafts = <ImportedStoryDraft>[];
    int skipped = 0;

    final List<List<dynamic>> rows;
    try {
      rows = const CsvDecoder(dynamicTyping: false).convert(content);
    } catch (_) {
      return const ImportedParseResult(drafts: [], skippedCount: 1);
    }

    if (rows.isEmpty) return const ImportedParseResult(drafts: [], skippedCount: 1);

    final header = rows.first.map((e) => e?.toString().trim().toLowerCase() ?? '').toList();
    int indexOf(String column) => header.indexOf(column);

    final dateTimeIdx = indexOf('date_time');
    final fullDateIdx = indexOf('full_date');
    final moodIdx = indexOf('mood_title');
    final activitiesIdx = indexOf('activities');
    final noteTitleIdx = indexOf('note_title');
    final noteIdx = indexOf('note');

    // Not a Daylio export (or a headerless/unknown CSV) — reject the whole file.
    if (dateTimeIdx < 0 && fullDateIdx < 0) {
      return const ImportedParseResult(drafts: [], skippedCount: 1);
    }

    for (final row in rows.skip(1)) {
      String cell(int index) => (index >= 0 && index < row.length) ? row[index]?.toString().trim() ?? '' : '';

      final date = _parseDate(cell(dateTimeIdx)) ?? _parseDate(cell(fullDateIdx));
      final noteTitle = cell(noteTitleIdx);
      final note = cell(noteIdx);

      if (date == null || (noteTitle.isEmpty && note.isEmpty)) {
        skipped++;
        continue;
      }

      final activities = cell(
        activitiesIdx,
      ).split(RegExp(r'[,;|]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      final body = [if (noteTitle.isNotEmpty) noteTitle, if (note.isNotEmpty) note].join('\n\n');

      drafts.add(
        ImportedStoryDraft(
          date: date,
          body: body,
          tags: activities,
          feeling: cell(moodIdx).isEmpty ? null : cell(moodIdx),
        ),
      );
    }

    return ImportedParseResult(drafts: drafts, skippedCount: skipped);
  }

  /// Daylio writes `date_time` as `dd/mm/yyyy HH:mm` (or `dd/mm/yyyy` in
  /// `full_date`). Some locales/versions use `-` or `.` separators.
  static DateTime? _parseDate(String value) {
    if (value.isEmpty) return null;

    final match = RegExp(r'^(\d{1,4})[/\-.](\d{1,2})[/\-.](\d{1,4})(?:\s+(\d{1,2}):(\d{2}))?$').firstMatch(value);
    if (match == null) return DateTime.tryParse(value);

    final a = int.parse(match.group(1)!);
    final b = int.parse(match.group(2)!);
    final c = int.parse(match.group(3)!);
    final hour = match.group(4) != null ? int.parse(match.group(4)!) : 0;
    final minute = match.group(5) != null ? int.parse(match.group(5)!) : 0;

    // Daylio is day-first (dd/mm/yyyy). A 4-digit first group means yyyy/mm/dd.
    if (a > 31) return DateTime(a, b, c, hour, minute);
    if (c > 31) return DateTime(c, b, a, hour, minute);
    // Ambiguous two-digit year — assume day-first with a 2000s year.
    return DateTime(2000 + (c < 100 ? c : 0), b, a, hour, minute);
  }
}
