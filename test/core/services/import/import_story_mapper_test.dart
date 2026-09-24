import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/objects/imported_story_draft.dart';
import 'package:storypad/core/services/import/import_story_mapper.dart';

void main() {
  test('embeds photos as structured Quill media ops, not markdown text', () {
    final draft = ImportedStoryDraft(
      date: DateTime(2024, 3, 1, 10, 0),
      body: 'A quiet morning walk.',
    );

    final story = ImportStoryMapper.toStory(
      draft: draft,
      id: 123,
      tagIds: ['1'],
      mediaPaths: ['images/111.jpg', 'images/222.png'],
      assetIds: [111, 222],
    );

    final body = story.latestContent!.richPages!.single.body!;

    // Body text insert first.
    expect(body.first['insert'], 'A quiet morning walk.\n');

    // Each photo becomes a structured media embed op + newline — NOT literal
    // markdown like "![](images/111.jpg)" inside a text insert.
    final embedOps = body.where((op) => op['insert'] is Map).toList();
    expect(embedOps, hasLength(2));
    expect(embedOps[0]['insert'], {'media': 'images/111.jpg'});
    expect(embedOps[1]['insert'], {'media': 'images/222.png'});

    final bodyText = body.map((op) => op['insert']).whereType<String>().join();
    expect(bodyText, isNot(contains('![](')));
  });

  test('links created asset ids onto story.assets', () {
    final draft = ImportedStoryDraft(date: DateTime(2024, 3, 1), body: 'note');

    final story = ImportStoryMapper.toStory(
      draft: draft,
      id: 42,
      tagIds: [],
      mediaPaths: ['images/111.jpg'],
      assetIds: [111],
    );

    expect(story.assets, [111]);
  });

  test('media-only entries (no body) still produce a valid delta', () {
    final draft = ImportedStoryDraft(date: DateTime(2024, 3, 1));

    final story = ImportStoryMapper.toStory(
      draft: draft,
      id: 42,
      tagIds: [],
      mediaPaths: ['images/111.jpg'],
      assetIds: [111],
    );

    final body = story.latestContent!.richPages!.single.body!;
    expect(body, hasLength(2));
    expect(body[0]['insert'], {'media': 'images/111.jpg'});
    expect(body[1]['insert'], '\n');
  });

  test('no photos → plain text delta, empty assets', () {
    final draft = ImportedStoryDraft(date: DateTime(2024, 3, 1), body: 'hello');

    final story = ImportStoryMapper.toStory(draft: draft, id: 42, tagIds: []);

    final body = story.latestContent!.richPages!.single.body!;
    expect(body, hasLength(1));
    expect(body.single['insert'], 'hello\n');
    expect(story.assets, isEmpty);
  });

  test('StoryContentDbModel.create round-trips title', () {
    final draft = ImportedStoryDraft(
      date: DateTime(2024, 3, 1),
      title: 'Trip',
      body: 'line1\nline2',
    );
    final story = ImportStoryMapper.toStory(draft: draft, id: 1, tagIds: []);
    expect(story.latestContent!.title, 'Trip');
  });
}
