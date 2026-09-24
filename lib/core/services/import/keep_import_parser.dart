import 'dart:convert';

import 'package:storypad/core/objects/imported_story_draft.dart';

/// Parses a single Google Keep JSON export note into an [ImportedStoryDraft].
///
/// Keep exports one `.json` file per note:
/// ```json
/// { "title": "Note title", "textContent": "plain text",
///   "textContentHtml": "<p>...</p>", "createdTimestampUtc": "1690000000000",
///   "userEditedTimestampUtc": "1690000000000", "labels": [ { "name": "food" } ] }
/// ```
class KeepImportParser {
  static ImportedStoryDraft? parse(String content) {
    dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    return parseNote(decoded);
  }

  static ImportedStoryDraft? parseNote(Map<dynamic, dynamic> note) {
    final createdMs = int.tryParse(note['createdTimestampUtc']?.toString() ?? '');
    final editedMs = int.tryParse(note['userEditedTimestampUtc']?.toString() ?? '');
    final date = _fromMillis(createdMs) ?? _fromMillis(editedMs);
    if (date == null) return null;

    // Prefer plain text; fall back to a rough HTML strip of textContentHtml.
    String? body = _nonEmpty(note['textContent']?.toString());
    body ??= _stripHtml(_nonEmpty(note['textContentHtml']?.toString()));

    // `listContent` (checklist notes) — flatten checked/unchecked items.
    final listContent = note['listContent'];
    if (body == null && listContent is List) {
      body = listContent
          .whereType<Map>()
          .map((item) => '${item['isChecked'] == true ? '[x] ' : '[ ] '}${item['text']?.toString() ?? ''}')
          .join('\n');
    }

    if (body == null || body.trim().isEmpty) return null;

    final labels = <String>[];
    final rawLabels = note['labels'];
    if (rawLabels is List) {
      for (final label in rawLabels) {
        if (label is! Map) continue;
        final name = label['name']?.toString().trim();
        if (name != null && name.isNotEmpty) labels.add(name);
      }
    }

    return ImportedStoryDraft(date: date, title: _nonEmpty(note['title']?.toString()), body: body.trim(), tags: labels);
  }

  static DateTime? _fromMillis(int? ms) {
    if (ms == null) return null;
    // Keep timestamps are UTC milliseconds since epoch.
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }

  static String? _nonEmpty(String? value) => (value == null || value.trim().isEmpty) ? null : value.trim();

  static String? _stripHtml(String? html) {
    if (html == null) return null;
    return html
        .replaceAll(RegExp(r'<br\s*/?>|</p>|</div>|</li>'), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
