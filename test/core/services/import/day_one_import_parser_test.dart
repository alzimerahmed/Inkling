import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/import/day_one_import_parser.dart';

/// Builds an in-memory zip with the given entries (path → bytes).
List<int> buildZip(Map<String, List<int>> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    final bytes = entry.value;
    archive.addFile(
      ArchiveFile(entry.key, bytes.length, Uint8List.fromList(bytes)),
    );
  }
  return ZipEncoder().encode(archive);
}

List<int> jpegBytes({int size = 10}) => List.filled(size, 0xFF);

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('day_one_parser_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('extracts photos and parses journal json', () async {
    final zip = buildZip({
      'Journal.json':
          '[{"creationDate":"2023-01-02T10:30:00Z","text":"hello","photos":[{"fileName":"IMG.jpg"}]}]'.codeUnits,
      'photos/IMG.jpg': jpegBytes(),
    });

    final result = await DayOneImportParser.parseZip(
      zipBytes: zip,
      tempPhotoDir: tempDir,
    );

    expect(result.drafts, hasLength(1));
    expect(result.drafts.single.body, 'hello');
    expect(result.photoFiles.keys, contains('img.jpg'));
    expect(File(result.photoFiles['img.jpg']!).existsSync(), isTrue);
  });

  test('entry-count cap stops processing a zip bomb with many files', () async {
    final Map<String, List<int>> entries = {
      'Journal.json': '[]'.codeUnits,
    };
    for (int i = 0; i < DayOneImportParser.maxZipEntries + 10; i++) {
      entries['photos/p$i.jpg'] = jpegBytes();
    }
    final zip = buildZip(entries);

    final result = await DayOneImportParser.parseZip(
      zipBytes: zip,
      tempPhotoDir: tempDir,
    );

    // Parsing still succeeds, but only up to the cap was extracted.
    expect(
      result.photoFiles.length,
      lessThanOrEqualTo(DayOneImportParser.maxZipEntries),
    );
  });

  test('per-file size cap skips oversized entries', () async {
    final zip = buildZip({
      'Journal.json': '[]'.codeUnits,
      'photos/small.jpg': jpegBytes(size: 10),
      'photos/huge.jpg': jpegBytes(
        size: DayOneImportParser.maxZipPerFileBytes + 1,
      ),
    });

    final result = await DayOneImportParser.parseZip(
      zipBytes: zip,
      tempPhotoDir: tempDir,
    );

    expect(result.photoFiles.keys, contains('small.jpg'));
    expect(result.photoFiles.keys, isNot(contains('huge.jpg')));
  });

  test('total uncompressed size cap stops extraction', () async {
    final Map<String, List<int>> entries = {'Journal.json': '[]'.codeUnits};
    const perFile = DayOneImportParser.maxZipTotalUncompressedBytes ~/ 3;
    entries['photos/a.jpg'] = jpegBytes(size: perFile);
    entries['photos/b.jpg'] = jpegBytes(size: perFile);
    final zip = buildZip(entries);

    final result = await DayOneImportParser.parseZip(
      zipBytes: zip,
      tempPhotoDir: tempDir,
    );

    expect(result.photoFiles.length, lessThan(2));
  });

  test('colliding basenames from different folders do not overwrite', () async {
    final zip = buildZip({
      'Journal.json': '[]'.codeUnits,
      'photos/a/x.jpg': jpegBytes(size: 1),
      'photos/b/x.jpg': jpegBytes(size: 2),
    });

    final result = await DayOneImportParser.parseZip(
      zipBytes: zip,
      tempPhotoDir: tempDir,
    );

    // First entry wins; only one temp file is registered for 'x.jpg'.
    expect(result.photoFiles, hasLength(1));
  });

  test('path traversal is mitigated (only the basename is used)', () async {
    final zip = buildZip({
      'Journal.json': '[]'.codeUnits,
      'photos/../../evil.jpg': jpegBytes(),
    });

    final result = await DayOneImportParser.parseZip(
      zipBytes: zip,
      tempPhotoDir: tempDir,
    );

    expect(result.photoFiles.keys, contains('evil.jpg'));
    // The extracted file lives inside the temp dir, not outside it.
    final extracted = File(result.photoFiles['evil.jpg']!);
    expect(extracted.parent.path.startsWith(tempDir.path), isTrue);
  });
}
