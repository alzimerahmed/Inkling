import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/databases/models/base_db_model.dart';
import 'package:storypad/core/databases/models/story_content_db_model.dart';
import 'package:storypad/core/databases/models/story_db_model.dart';
import 'package:storypad/core/databases/models/story_page_db_model.dart';
import 'package:storypad/core/objects/backup_file_object.dart';
import 'package:storypad/core/objects/backup_object.dart';
import 'package:storypad/core/objects/device_info_object.dart';
import 'package:storypad/core/services/backups/sync_steps/utils/json_tables_to_model_service.dart';
import 'package:storypad/core/types/path_type.dart';

/// Round-trip guard for the backup payload itself: model → backup JSON → model.
///
/// This is the serialization half of "create → export → wipe → restore":
/// a story is converted to its backup-table JSON, wrapped in a [BackupObject],
/// encoded/decoded through JSON (simulating the tar file write + read), and
/// decoded back into models. Any field dropped, renamed, or mangled by the
/// backup format fails here — without needing a live ObjectBox store.
void main() {
  StoryPageDbModel buildPage({required int id, required String title}) {
    return StoryPageDbModel(
      id: id,
      title: title,
      body: [
        {'insert': 'A quiet morning walk.\n'},
        {'insert': 'The city was still asleep.\n'},
      ],
      wordCount: 9,
      characterCount: 47,
    );
  }

  StoryDbModel buildStory({
    required int id,
    required int year,
    required int month,
    required int day,
  }) {
    final DateTime now = DateTime(year, month, day, 9, 30);
    final StoryContentDbModel content = StoryContentDbModel(
      id: id * 10,
      title: 'Morning pages',
      plainText: 'A quiet morning walk.\nThe city was still asleep.\n',
      createdAt: now,
      richPages: [
        buildPage(id: id * 100, title: 'Page 1'),
        buildPage(id: id * 100 + 1, title: 'Page 2'),
      ],
    );

    return StoryDbModel(
      type: PathType.docs,
      id: id,
      starred: true,
      pinned: false,
      feeling: 'relaxed',
      year: year,
      month: month,
      day: day,
      hour: 9,
      minute: 30,
      second: 0,
      createdAt: now,
      updatedAt: now.add(const Duration(hours: 1)),
      tags: ['1', '42'],
      assets: [],
      movedToBinAt: null,
      latestContent: content,
      draftContent: null,
      galleryTemplateId: null,
      templateId: null,
      lastSavedDeviceId: 'test-device',
      permanentlyDeletedAt: null,
    );
  }

  BackupObject buildBackup(Map<String, dynamic> tables, DateTime createdAt) {
    return BackupObject(
      tables: tables,
      fileInfo: BackupFileObject(
        createdAt: createdAt,
        device: DeviceInfoObject(model: 'test-device', id: 'test-device'),
        version: '2',
        year: null,
        hasCompression: false,
      ),
    );
  }

  group('backup JSON round-trip', () {
    test('story survives backup encode → JSON file → decode unchanged', () {
      final StoryDbModel story = buildStory(
        id: 1,
        year: 2026,
        month: 9,
        day: 1,
      );

      // 1. Serialize into a backup payload (what the tar file contains).
      final Map<String, dynamic> contents = buildBackup(
        {
          'stories': [story.toJson()],
        },
        story.updatedAt,
      ).toContents();

      // 2. Simulate the file write + read: JSON encode then decode.
      final Map<String, dynamic> fromFile = jsonDecode(jsonEncode(contents));

      // 3. Restore: decode tables back into models.
      final Map<String, List<BaseDbModel>> decoded = JsonTablesToModelService.decode(
        fromFile['tables'] as Map<String, dynamic>,
      );
      final StoryDbModel restored = decoded['stories']!.first as StoryDbModel;

      expect(restored.toJson(), story.toJson());
    });

    test('multiple stories survive the round-trip', () {
      final List<StoryDbModel> stories = [
        buildStory(id: 1, year: 2025, month: 12, day: 31),
        buildStory(id: 2, year: 2026, month: 1, day: 1),
        buildStory(id: 3, year: 2026, month: 9, day: 22),
      ];

      final Map<String, dynamic> contents = buildBackup(
        {
          'stories': [for (final story in stories) story.toJson()],
        },
        stories.last.updatedAt,
      ).toContents();

      final Map<String, dynamic> fromFile = jsonDecode(jsonEncode(contents));
      final decoded = JsonTablesToModelService.decode(
        fromFile['tables'] as Map<String, dynamic>,
      );

      expect(decoded['stories']!.length, 3);
      expect(
        [for (final item in decoded['stories']!) item.toJson()],
        [for (final story in stories) story.toJson()],
      );
    });

    test(
      'backup payload carries file metadata needed for restore decisions',
      () {
        final StoryDbModel story = buildStory(
          id: 1,
          year: 2026,
          month: 9,
          day: 1,
        );

        final Map<String, dynamic> contents = buildBackup(
          {
            'stories': [story.toJson()],
          },
          story.updatedAt,
        ).toContents();

        final Map<String, dynamic> fromFile = jsonDecode(jsonEncode(contents));
        final BackupObject restored = BackupObject.fromContents(fromFile);

        expect(restored.tables['stories'], isA<List>());
        expect(restored.fileInfo.createdAt, story.updatedAt);
        expect(
          restored.year,
          isNull,
          reason: 'full backups are not year-partitioned',
        );
      },
    );
  });
}
