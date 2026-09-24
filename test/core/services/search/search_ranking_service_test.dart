import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/databases/models/story_content_db_model.dart';
import 'package:storypad/core/databases/models/story_db_model.dart';
import 'package:storypad/core/databases/models/story_page_db_model.dart';
import 'package:storypad/core/services/search/search_ranking_service.dart';
import 'package:storypad/core/types/path_type.dart';

StoryDbModel _story({
  required int id,
  required DateTime date,
  String? title,
  String? plainText,
}) {
  final content = StoryContentDbModel.create(createdAt: date).copyWith(
    title: title,
    plainText: plainText,
    richPages: [
      StoryPageDbModel(
        id: id,
        title: title,
        body: [
          {'insert': '${plainText ?? ''}\n'},
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
    year: date.year,
    month: date.month,
    day: date.day,
    hour: date.hour,
    minute: date.minute,
    second: date.second,
    updatedAt: date,
    createdAt: date,
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
  group('SearchRankingService.rank', () {
    test('title matches rank above body matches', () {
      final bodyMatch = _story(
        id: 1,
        date: DateTime(2024, 1, 1),
        title: 'Other',
        plainText: 'garden visit',
      );
      final titleMatch = _story(
        id: 2,
        date: DateTime(2023, 1, 1),
        title: 'Garden plans',
        plainText: 'nothing relevant',
      );

      final stories = [bodyMatch, titleMatch];
      SearchRankingService.rank(stories, 'garden');

      expect(stories.first.id, titleMatch.id);
    });

    test('more occurrences rank above fewer', () {
      final one = _story(id: 1, date: DateTime(2024, 1, 1), plainText: 'garden once');
      final many = _story(id: 2, date: DateTime(2024, 1, 1), plainText: 'garden garden garden');
      final stories = [one, many];

      SearchRankingService.rank(stories, 'garden');
      expect(stories.first.id, many.id);
    });

    test('no query keeps order untouched', () {
      final a = _story(id: 1, date: DateTime(2024, 1, 1), plainText: 'x');
      final b = _story(id: 2, date: DateTime(2024, 1, 1), plainText: 'y');
      final stories = [a, b];

      SearchRankingService.rank(stories, null);
      expect(stories.map((s) => s.id), [1, 2]);
    });
  });
}
