import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
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
/// Fonts: the built-in PDF Helvetica base-14 font only covers WinAnsi
/// (Latin-1-ish) text — non-Latin stories (Cyrillic, Greek, Arabic, CJK, …)
/// cannot be encoded with it. Callers must therefore pass Unicode TTFs via
/// [fontBytes]; the first one becomes the base font, the rest are used as
/// fallbacks glyph-by-glyph. Inkling bundles Noto Sans (Latin/Greek/Cyrillic)
/// and Noto Sans Arabic (SIL OFL 1.0, see `assets/fonts/OFL-*.txt`).
///
/// Known limitation: CJK/Thai/Devanagari and other scripts without a bundled
/// font render as `.notdef` boxes — they no longer crash the export, but full
/// coverage would require bundling much larger Noto CJK fonts (~10 MB+).
///
/// Each story starts on a new page (per-entry export); a date-range export is
/// simply the caller passing the filtered story list.
class ExportStoriesToPdfService {
  /// Returns the complete PDF byte stream.
  ///
  /// [tagNames] maps tag ids to their titles and must be resolved by the
  /// caller on the main isolate — ObjectBox stores cannot be touched inside
  /// `Isolate.run`, and this service runs there.
  static Future<List<int>> call({
    required List<StoryDbModel> stories,
    Map<int, String> tagNames = const {},
    List<Uint8List> fontBytes = const [],
    String tagsLabel = 'Tags: ',
    String photoPlaceholder = '[photo]',
  }) async {
    final doc = pw.Document(
      theme: _buildTheme(fontBytes),
    );

    for (final story in stories) {
      final content = story.draftContent ?? story.latestContent;
      if (content == null) continue;

      final tagNamesForStory = <String>[];
      if (story.validTags?.isNotEmpty == true) {
        for (final tagId in story.validTags!) {
          final name = tagNames[tagId];
          if (name != null && name.isNotEmpty) tagNamesForStory.add(name);
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
            if (tagNamesForStory.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text(
                  '$tagsLabel${tagNamesForStory.join(', ')}',
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
                photoPlaceholder,
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

  /// Loads the bundled Unicode fonts (main isolate only — asset bundles are
  /// not reachable inside `Isolate.run`). Missing assets are skipped so the
  /// export still works (with the Helvetica limitation) if they ever change.
  static Future<List<Uint8List>> loadBundledFonts() async {
    const fontAssets = [
      'assets/fonts/NotoSans-Regular.ttf', // Latin/Greek/Cyrillic
      'assets/fonts/NotoSansArabic-Regular.ttf', // Arabic
    ];
    final fonts = <Uint8List>[];
    for (final asset in fontAssets) {
      try {
        final data = await rootBundle.load(asset);
        fonts.add(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      } catch (_) {
        // Font missing — fall through; non-WinAnsi text will render as boxes.
      }
    }
    return fonts;
  }

  /// Builds a document theme from the given TTF bytes. The first font is the
  /// base (and bold — the `pdf` package does not synthesize a bold cut), the
  /// remaining ones are fallbacks for scripts the base font doesn't cover.
  static pw.ThemeData? _buildTheme(List<Uint8List> fontBytes) {
    if (fontBytes.isEmpty) return null;
    final fonts = fontBytes.map((bytes) => pw.Font.ttf(ByteData.sublistView(bytes))).toList();
    return pw.ThemeData.withFont(
      base: fonts.first,
      bold: fonts.first,
      fontFallback: fonts.length > 1 ? fonts.sublist(1) : <pw.Font>[],
    );
  }
}
