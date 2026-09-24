import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/databases/models/story_content_db_model.dart';
import 'package:storypad/core/databases/models/story_db_model.dart';
import 'package:storypad/core/databases/models/story_page_db_model.dart';
import 'package:storypad/core/services/export/export_stories_to_pdf_service.dart';
import 'package:storypad/core/types/path_type.dart';

StoryDbModel _story({required int id, String? title, String? body, DateTime? date}) {
  final entryDate = date ?? DateTime(2023, 5, 1, 9, 30);
  final content = StoryContentDbModel.create(createdAt: entryDate).copyWith(
    title: title,
    richPages: [
      StoryPageDbModel(
        id: id,
        title: title,
        body: [
          {'insert': '${body ?? 'Body text'}\n'},
        ],
      ),
    ],
  );

  return StoryDbModel(
    type: PathType.docs,
    id: id,
    starred: false,
    pinned: false,
    feeling: null,
    year: entryDate.year,
    month: entryDate.month,
    day: entryDate.day,
    hour: entryDate.hour,
    minute: entryDate.minute,
    second: entryDate.second,
    updatedAt: entryDate,
    createdAt: entryDate,
    lastSavedDeviceId: null,
    galleryTemplateId: null,
    templateId: null,
    tags: [],
    assets: [],
    movedToBinAt: null,
    latestContent: content,
    draftContent: null,
    permanentlyDeletedAt: null,
  );
}

void main() {
  group('ExportStoriesToPdfService', () {
    test('produces a valid PDF byte stream', () async {
      final bytes = await ExportStoriesToPdfService.call(
        stories: [_story(id: 1, title: 'My Entry', body: 'Hello PDF')],
      );

      expect(bytes, isNotEmpty);
      // PDF files start with the %PDF- header.
      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
      // PDF files end with the %%EOF marker.
      final tail = utf8.decode(bytes.sublist(bytes.length - 8));
      expect(tail, contains('%%EOF'));
    });

    test('produces one document for multiple entries', () async {
      final bytes = await ExportStoriesToPdfService.call(
        stories: [
          _story(id: 1, title: 'First', body: 'A'),
          _story(id: 2, title: 'Second', body: 'B'),
        ],
      );

      expect(bytes, isNotEmpty);
      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
    });

    test('skips stories without content', () async {
      final bytes = await ExportStoriesToPdfService.call(stories: []);
      expect(bytes, isNotEmpty);
      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
    });
  });
}
