import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/objects/imported_story_draft.dart';
import 'package:storypad/core/services/import/import_story_mapper.dart';
import 'package:storypad/core/types/path_type.dart';

void main() {
  group('ImportStoryMapper.toStory', () {
    test('maps date fields, tags, feeling and delta body', () {
      final story = ImportStoryMapper.toStory(
        draft: ImportedStoryDraft(
          date: DateTime(2023, 1, 2, 10, 30, 5),
          title: 'Title',
          body: 'Body text',
          tags: ['1', '2'],
          feeling: 'Happy',
        ),
        id: 123,
        tagIds: ['1', '2'],
      );

      expect(story.id, 123);
      expect(story.type, PathType.docs);
      expect(story.year, 2023);
      expect(story.month, 1);
      expect(story.day, 2);
      expect(story.hour, 10);
      expect(story.minute, 30);
      expect(story.feeling, 'Happy');
      expect(story.tags, ['1', '2']);
      expect(story.latestContent?.title, 'Title');
      expect(story.latestContent?.richPages?.first.body, [
        {'insert': 'Body text\n'},
      ]);
    });

    test('promotes a short first line to title for body-only drafts', () {
      final story = ImportStoryMapper.toStory(
        draft: ImportedStoryDraft(date: DateTime(2023, 1, 2), body: 'Short title\nLonger body follows here'),
        id: 456,
        tagIds: [],
      );

      expect(story.latestContent?.title, 'Short title');
    });

    test('does not promote a long single-line body to title', () {
      final longLine = 'a' * 100;
      final story = ImportStoryMapper.toStory(
        draft: ImportedStoryDraft(date: DateTime(2023, 1, 2), body: longLine),
        id: 789,
        tagIds: [],
      );

      expect(story.latestContent?.title, isNull);
    });
  });
}
