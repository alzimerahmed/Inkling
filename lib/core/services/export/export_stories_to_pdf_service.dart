import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:storypad/core/databases/models/story_db_model.dart';
import 'package:storypad/core/services/quill/quill_delta_to_plain_text_service.dart';

/// Exports stories to a PDF document using the pure-Dart `pdf` package
/// (Apache-2.0 — F-Droid compatible, see docs/research.md ADR-006).
///
/// Scope: text-only (title, date, tags, plain-text body). Embedded images are
/// rendered as a `[photo]` placeholder line — decoding arbitrary image bytes
/// into PDF XObjects for every format is out of scope for v1.
///
/// Each story starts on a new page (per-entry export); a date-range export is
/// simply the caller passing the filtered story list.
class ExportStoriesToPdfService {
  /// Returns the complete PDF byte stream.
  static Future<List<int>> call({
    required List<StoryDbModel> stories,
    Future<String?> Function(int tagId)? tagNameGetter,
  }) async {
    final doc = pw.Document();

    for (final story in stories) {
      final content = story.draftContent ?? story.latestContent;
      if (content == null) continue;

      final tagNames = <String>[];
      if (story.validTags?.isNotEmpty == true && tagNameGetter != null) {
        for (final tagId in story.validTags!) {
          final name = await tagNameGetter(tagId);
          if (name != null && name.isNotEmpty) tagNames.add(name);
        }
      }

      final date = story.displayPathDate;
      final dateStr =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';

      final bodyText = content.richPages
          ?.map((page) {
            if (page.body == null) return '';
            return QuillDeltaToPlainTextService.call(
              page.body!,
              markdown: false,
              includeMarkdownEmbeds: false,
            );
          })
          .where((t) => t.trim().isNotEmpty)
          .join('\n\n');

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(48),
          build: (context) => [
            if (content.title?.trim().isNotEmpty == true)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  content.title!,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            pw.Text(
              dateStr,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            if (tagNames.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text(
                  'Tags: ${tagNames.join(', ')}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 12),
              child: pw.Divider(),
            ),
            if (bodyText != null && bodyText.trim().isNotEmpty)
              pw.Text(bodyText, style: const pw.TextStyle(fontSize: 12))
            else
              pw.Text(
                '[photo]',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey400,
                ),
              ),
          ],
        ),
      );
    }

    return doc.save();
  }
}
