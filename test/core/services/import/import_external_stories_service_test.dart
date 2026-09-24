import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/databases/models/tag_db_model.dart';
import 'package:storypad/core/objects/imported_story_draft.dart';
import 'package:storypad/core/services/import/import_external_stories_service.dart';

TagDbModel existingTag(int id, String title) => TagDbModel(
  id: id,
  version: 0,
  title: title,
  emoji: null,
  categoryId: null,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
  lastSavedDeviceId: null,
  permanentlyDeletedAt: null,
);

void main() {
  Future<String> fakeCreateTag(String title) async => 'created:$title';
  Future<String> fakeCreateFeelingTag(String title) async => 'feeling:$title';

  test('dedupes tag titles case-insensitively across drafts', () async {
    final drafts = [
      ImportedStoryDraft(
        date: DateTime(2024),
        body: 'a',
        tags: ['Gym', 'gym ', 'Work'],
      ),
      ImportedStoryDraft(date: DateTime(2024), body: 'b', tags: ['GYM']),
    ];

    final result = await ImportExternalStoriesService.resolveTagIds(
      drafts: drafts,
      existingTagsByTitle: {},
      createTag: fakeCreateTag,
      createFeelingTag: fakeCreateFeelingTag,
    );

    // 'gym' resolved once despite 4 differently-cased spellings.
    expect(result.idsByTitle.keys, hasLength(2));
    expect(result.createdCount, 2); // gym + work
  });

  test('pre-existing tags are reused and NOT counted as created', () async {
    final drafts = [
      ImportedStoryDraft(
        date: DateTime(2024),
        body: 'a',
        tags: ['existing', 'brand-new'],
      ),
    ];

    final result = await ImportExternalStoriesService.resolveTagIds(
      drafts: drafts,
      existingTagsByTitle: {
        'existing': existingTag(7, 'existing'),
      },
      createTag: fakeCreateTag,
      createFeelingTag: fakeCreateFeelingTag,
    );

    expect(result.idsByTitle['existing'], '7');
    expect(result.createdCount, 1); // only 'brand-new'
  });

  test('Daylio: activities stay plain tags, mood maps to feeling', () async {
    final drafts = [
      ImportedStoryDraft(
        date: DateTime(2024),
        body: 'a',
        tags: ['gym', 'work'],
        feeling: 'Good',
      ),
    ];

    final result = await ImportExternalStoriesService.resolveTagIds(
      drafts: drafts,
      existingTagsByTitle: {},
      createTag: fakeCreateTag,
      createFeelingTag: fakeCreateFeelingTag,
      mapMoodToFeelingTag: true,
    );

    expect(result.idsByTitle['gym'], 'created:gym');
    expect(result.idsByTitle['work'], 'created:work');
    expect(result.idsByTitle['good'], 'feeling:Good');
    expect(result.createdCount, 3);
  });

  test('without the flag, the mood does NOT become a tag', () async {
    final drafts = [
      ImportedStoryDraft(
        date: DateTime(2024),
        body: 'a',
        tags: [],
        feeling: 'Good',
      ),
    ];

    final result = await ImportExternalStoriesService.resolveTagIds(
      drafts: drafts,
      existingTagsByTitle: {},
      createTag: fakeCreateTag,
      createFeelingTag: fakeCreateFeelingTag,
    );

    expect(result.idsByTitle, isEmpty);
    expect(result.createdCount, 0);
  });

  test('shiftIdUntilFree skips taken ids (collision shifting)', () async {
    final taken = {100, 101, 102};
    final id = await ImportExternalStoriesService.shiftIdUntilFree(
      100,
      (id) async => taken.contains(id),
    );
    expect(id, 102 + 1); // first free id after the occupied run
  });

  test('shiftIdUntilFree returns the desired id when free', () async {
    final id = await ImportExternalStoriesService.shiftIdUntilFree(
      100,
      (id) async => false,
    );
    expect(id, 100);
  });
}
