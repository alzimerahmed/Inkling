import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:storypad/core/objects/imported_story_draft.dart';

/// Parses a Day One export (JSON or .zip containing JSON + photos) into
/// [ImportedStoryDraft]s.
///
/// Day One JSON shape (both variants seen in the wild):
/// ```json
/// [ { "creationDate": "2023-01-02T10:30:00Z", "text": "...",
///     "tags": ["a"], "mood": "Happy",
///     "photos": [ { "identifier": "IMG", "fileName": "IMG.jpg" } ] } ]
/// ```
/// or `{ "entries": [ ... ] }`.
///
/// Zip exports contain `Journal.json`/`Export.json` plus a `photos/` (or
/// `Exported Photos/`) folder. Photos are extracted to [tempPhotoDir] while
/// parsing (this whole parser runs off the main isolate) so the importer can
/// copy them into asset storage later.
class DayOneImportParser {
  static const List<String> _jsonEntryNames = [
    'Journal.json',
    'Export.json',
    'journal.json',
    'export.json',
  ];

  // Zip-bomb protection: a maliciously crafted export can declare tiny
  // compressed bytes that expand to gigabytes. Cap entry count, per-file
  // uncompressed size and total uncompressed size.
  static const int maxZipEntries = 5000;
  static const int maxZipTotalUncompressedBytes = 512 * 1024 * 1024; // 512 MB
  static const int maxZipPerFileBytes = 100 * 1024 * 1024; // 100 MB

  /// Parses a `.json` Day One export. Photos are referenced by name but no
  /// photo bytes exist in a bare JSON export — the importer records them as
  /// skipped warnings.
  static ImportedParseResult parseJson(String content) {
    final drafts = <ImportedStoryDraft>[];
    int skipped = 0;

    dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      return const ImportedParseResult(drafts: [], skippedCount: 1);
    }

    List<dynamic>? entries;
    if (decoded is List) {
      entries = decoded;
    } else if (decoded is Map) {
      entries = decoded['entries'] as List<dynamic>?;
    }

    if (entries == null) return const ImportedParseResult(drafts: [], skippedCount: 1);

    for (final entry in entries) {
      if (entry is! Map) {
        skipped++;
        continue;
      }
      final draft = _draftFromEntry(entry);
      if (draft == null) {
        skipped++;
      } else {
        drafts.add(draft);
      }
    }

    return ImportedParseResult(drafts: drafts, skippedCount: skipped);
  }

  /// Parses a `.zip` Day One export: extracts the JSON + photo files into
  /// [tempPhotoDir] (created by the caller), then parses the JSON.
  static Future<ImportedParseResult> parseZip({
    required List<int> zipBytes,
    required Directory tempPhotoDir,
  }) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (_) {
      return const ImportedParseResult(drafts: [], skippedCount: 1);
    }

    await tempPhotoDir.create(recursive: true);
    final photoFiles = <String, String>{};
    String? jsonContent;
    int totalUncompressed = 0;
    int entryCount = 0;

    for (final file in archive.files) {
      if (!file.isFile) continue;

      // Zip-bomb caps — checked against the declared uncompressed size before
      // decompressing anything.
      entryCount++;
      if (entryCount > maxZipEntries) break;
      totalUncompressed += file.size;
      if (totalUncompressed > maxZipTotalUncompressedBytes) break;
      if (file.size > maxZipPerFileBytes) continue;

      final name = file.name.split('/').last;
      if (name.isEmpty || name == '.' || name == '..') continue;
      final lower = name.toLowerCase();
      if (_jsonEntryNames.any(lower.endsWith) && jsonContent == null) {
        jsonContent = utf8.decode(file.content as List<int>);
        continue;
      }
      final ext = name.contains('.') ? name.substring(name.lastIndexOf('.')) : '';
      if ([
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.heic',
        '.webp',
      ].contains(ext.toLowerCase())) {
        // Colliding basenames from different folders (a/x.jpg vs b/x.jpg):
        // first one wins instead of silently overwriting.
        if (photoFiles.containsKey(lower)) continue;
        final tempFile = File('${tempPhotoDir.path}/$name');
        await tempFile.writeAsBytes(file.content as List<int>);
        photoFiles[lower] = tempFile.path;
      }
    }

    if (jsonContent == null) {
      return ImportedParseResult(
        drafts: const [],
        skippedCount: 1,
        photoFiles: photoFiles,
      );
    }

    final result = parseJson(jsonContent);
    return ImportedParseResult(
      drafts: result.drafts,
      skippedCount: result.skippedCount,
      photoFiles: photoFiles,
    );
  }

  static ImportedStoryDraft? _draftFromEntry(Map<dynamic, dynamic> entry) {
    final date = DateTime.tryParse(entry['creationDate']?.toString() ?? '');
    if (date == null) return null;

    final text = entry['text']?.toString();
    if (text == null || text.trim().isEmpty) return null;

    final tags = <String>[];
    final rawTags = entry['tags'];
    if (rawTags is List) {
      tags.addAll(
        rawTags.whereType<String>().where((t) => t.trim().isNotEmpty),
      );
    }

    final photos = <String>[];
    final rawPhotos = entry['photos'];
    if (rawPhotos is List) {
      for (final photo in rawPhotos) {
        if (photo is! Map) continue;
        final fileName = photo['fileName']?.toString() ?? photo['identifier']?.toString();
        if (fileName != null && fileName.trim().isNotEmpty) photos.add(fileName);
      }
    }

    return ImportedStoryDraft(
      date: date,
      body: text.trim(),
      tags: tags,
      feeling: _nonEmpty(entry['mood']?.toString()),
      photoFileNames: photos,
    );
  }

  static String? _nonEmpty(String? value) => (value == null || value.trim().isEmpty) ? null : value.trim();
}
