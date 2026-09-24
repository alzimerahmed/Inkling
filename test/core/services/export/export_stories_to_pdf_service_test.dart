import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/databases/models/story_content_db_model.dart';
import 'package:storypad/core/databases/models/story_db_model.dart';
import 'package:storypad/core/databases/models/story_page_db_model.dart';
import 'package:storypad/core/services/export/export_stories_to_pdf_service.dart';
import 'package:storypad/core/types/path_type.dart';

StoryDbModel buildStory({
  required int id,
  required String body,
  List<int> tagIds = const [],
}) {
  final date = DateTime(2024, 3, 1, 9, 30);
  return StoryDbModel(
    type: PathType.docs,
    id: id,
    starred: false,
    pinned: false,
    feeling: null,
    year: date.year,
    month: date.month,
    day: date.day,
    hour: date.hour,
    minute: date.minute,
    second: date.second,
    createdAt: date,
    updatedAt: date,
    lastSavedDeviceId: null,
    galleryTemplateId: null,
    templateId: null,
    tags: tagIds.map((e) => e.toString()).toList(),
    assets: [],
    movedToBinAt: null,
    latestContent: StoryContentDbModel.create(createdAt: date).copyWith(
      title: 'Дневник / 日記',
      richPages: [
        StoryPageDbModel(
          id: id,
          title: 'Дневник / 日記',
          body: [
            {'insert': '$body\n'},
          ],
        ),
      ],
    ),
    draftContent: null,
    permanentlyDeletedAt: null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'PDF export renders non-Latin (Cyrillic/Arabic/CJK) text with bundled Unicode fonts',
    () async {
      final fontBytes = await ExportStoriesToPdfService.loadBundledFonts();
      expect(
        fontBytes,
        isNotEmpty,
        reason: 'bundled Noto fonts must ship as assets',
      );

      final bytes = await ExportStoriesToPdfService.call(
        stories: [
          buildStory(id: 1, body: 'Привет мир — مرحبا بالعالم — 你好世界'),
          buildStory(id: 2, body: 'Plain latin entry'),
        ],
        tagNames: {1: 'работа', 2: 'رحلات'},
        fontBytes: fontBytes,
        tagsLabel: 'Tags: ',
        photoPlaceholder: '[photo]',
      );

      expect(bytes, isNotEmpty);
      // PDF magic header.
      expect(bytes.sublist(0, 5), '%PDF-'.codeUnits);
    },
  );

  test(
    'PDF export works without fonts (legacy fallback) for Latin text',
    () async {
      final bytes = await ExportStoriesToPdfService.call(
        stories: [buildStory(id: 1, body: 'Plain latin entry')],
        tagNames: {},
      );

      expect(bytes, isNotEmpty);
    },
  );
}
