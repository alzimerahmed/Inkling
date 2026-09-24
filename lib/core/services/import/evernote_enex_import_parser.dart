import 'package:html_character_entities/html_character_entities.dart';
import 'package:storypad/core/objects/imported_story_draft.dart';

/// Parses an Evernote ENEX export (XML) into [ImportedStoryDraft]s.
///
/// ENEX shape:
/// ```xml
/// <en-export><note>
///   <title>Note title</title>
///   <created>20230102T103000Z</created>
///   <updated>...</updated>
///   <tag>work</tag>
///   <content><![CDATA[ <?xml...<en-note><p>text</p>... </en-note> ?> ]]></content>
/// </note></en-export>
/// ```
///
/// Pragmatic scope: titles, dates, tags and plain-text content. Embedded
/// images/resources inside `<en-media>` are skipped (noted as warnings) —
/// ENEX stores them as base64 `<data>` blobs which we do not decode.
///
/// Implementation note: ENEX is parsed with regexes instead of an XML library
/// on purpose — `webdav_client` pins `xml ^6` while `pdf` requires `xml ^7`,
/// so adding a shared XML parser is impossible without a resolver conflict.
/// ENEX is machine-generated with a stable flat structure, so this is safe.
class EvernoteEnexImportParser {
  static ImportedParseResult parse(String content) {
    final drafts = <ImportedStoryDraft>[];
    int skipped = 0;

    final noteMatches = RegExp(
      r'<note>([\s\S]*?)</note>',
    ).allMatches(content).toList();
    if (noteMatches.isEmpty) return const ImportedParseResult(drafts: [], skippedCount: 1);

    for (final noteMatch in noteMatches) {
      final note = noteMatch.group(1)!;

      final date = _parseEnDate(_element(note, 'created')) ?? _parseEnDate(_element(note, 'updated'));
      if (date == null) {
        skipped++;
        continue;
      }

      final title = _element(note, 'title')?.trim();
      // Content is CDATA — entity decoding happens once in _enmlToPlainText.
      final enml = _element(note, 'content', decodeEntities: false) ?? '';
      final bodyText = _enmlToPlainText(enml);
      // Title-only notes still carry content — keep them instead of dropping.
      final body = bodyText.trim().isNotEmpty ? bodyText : (title ?? '');
      if (body.trim().isEmpty) {
        skipped++;
        continue;
      }

      final tags = RegExp(r'<tag>([\s\S]*?)</tag>')
          .allMatches(note)
          .map((m) => HtmlCharacterEntities.decode(m.group(1)!).trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final warnings = <String>[];
      if (note.contains('<resource>') || note.contains('<en-media')) warnings.add('attachments_skipped');

      drafts.add(
        ImportedStoryDraft(
          date: date,
          title: (title == null || title.isEmpty) ? null : title,
          body: body.trim(),
          tags: tags,
          warnings: warnings,
        ),
      );
    }

    return ImportedParseResult(drafts: drafts, skippedCount: skipped);
  }

  /// Inner text of the first `<name>…</name>` element (no nesting in ENEX).
  static String? _element(
    String xml,
    String name, {
    bool decodeEntities = true,
  }) {
    final match = RegExp('<$name>([\\s\\S]*?)</$name>').firstMatch(xml);
    if (match == null) return null;
    // CDATA close marker survives tag-stripping — drop it here.
    final raw = match.group(1)!.replaceAll(']]>', '');
    return decodeEntities ? HtmlCharacterEntities.decode(raw) : raw;
  }

  /// Evernote date format: `20230102T103000Z`.
  static DateTime? _parseEnDate(String? value) {
    if (value == null) return null;
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$',
    ).firstMatch(value.trim());
    if (match == null) return null;
    return DateTime.utc(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    ).toLocal();
  }

  /// Rough ENML → plain text: drop media/resource tags, convert block tags to
  /// newlines, strip remaining tags, decode entities.
  static String _enmlToPlainText(String enml) {
    return enml
        .replaceAll(RegExp(r'<en-media[^>]*>[\s\S]*?</en-media>'), '')
        .replaceAll(RegExp(r'<en-media[^>]*/>'), '')
        .replaceAll(RegExp(r'<en-todo[^>]*checked="true"\s*/?>'), '[x] ')
        .replaceAll(RegExp(r'<en-todo[^>]*/?>'), '[ ] ')
        .replaceAll(RegExp(r'<(br|/p|/div|/li|/h[1-6]|/en-note)[^>]*>'), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .split('\n')
        .map((line) => HtmlCharacterEntities.decode(line.trim()))
        .join('\n')
        .trim();
  }
}
