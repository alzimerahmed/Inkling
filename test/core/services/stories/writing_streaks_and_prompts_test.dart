import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/databases/models/story_content_db_model.dart';
import 'package:storypad/core/databases/models/story_db_model.dart';
import 'package:storypad/core/databases/models/story_page_db_model.dart';
import 'package:storypad/core/objects/stats/stats_range.dart';
import 'package:storypad/core/services/journaling_prompts_service.dart';
import 'package:storypad/core/services/stories/story_stats_service.dart';
import 'package:storypad/core/services/stories/writing_goal_service.dart';
import 'package:storypad/core/types/path_type.dart';

StoryDbModel _story({
  required int id,
  required int year,
  required int month,
  required int day,
  int words = 10,
}) {
  final DateTime now = DateTime(year, month, day, 9);
  return StoryDbModel(
    type: PathType.docs,
    id: id,
    starred: false,
    pinned: false,
    feeling: null,
    year: year,
    month: month,
    day: day,
    hour: 9,
    minute: 0,
    second: 0,
    createdAt: now,
    updatedAt: now,
    tags: [],
    assets: [],
    movedToBinAt: null,
    latestContent: StoryContentDbModel(
      id: id * 10,
      title: null,
      plainText: 'x ' * words,
      createdAt: now,
      richPages: [
        StoryPageDbModel(
          id: id * 100,
          title: null,
          body: const [],
          wordCount: words,
        ),
      ],
    ),
    draftContent: null,
    galleryTemplateId: null,
    templateId: null,
    lastSavedDeviceId: null,
    permanentlyDeletedAt: null,
  );
}

void main() {
  group('streaks', () {
    test('current streak counts consecutive days ending today', () {
      final stats = StoryStatsService.compute(
        stories: [
          _story(id: 1, year: 2024, month: 6, day: 1),
          _story(id: 2, year: 2024, month: 6, day: 2),
          _story(id: 3, year: 2024, month: 6, day: 3),
          _story(id: 4, year: 2024, month: 6, day: 5), // gap breaks the streak
        ],
        allTags: [],
        range: StatsRange.month(DateTime(2024, 6, 1)),
        now: DateTime(2024, 6, 5),
      );

      expect(stats.currentStreak, 1);
      expect(stats.longestStreak, 3);
    });

    test('an unwritten today does not break an ongoing streak', () {
      final stats = StoryStatsService.compute(
        stories: [
          _story(id: 1, year: 2024, month: 6, day: 1),
          _story(id: 2, year: 2024, month: 6, day: 2),
          _story(id: 3, year: 2024, month: 6, day: 3),
        ],
        allTags: [],
        range: StatsRange.month(DateTime(2024, 6, 1)),
        now: DateTime(2024, 6, 4), // nothing written today
      );

      expect(stats.currentStreak, 3);
    });

    test('no stories means no streaks', () {
      final stats = StoryStatsService.compute(
        stories: [],
        allTags: [],
        range: StatsRange.month(DateTime(2024, 6, 1)),
        now: DateTime(2024, 6, 5),
      );

      expect(stats.currentStreak, 0);
      expect(stats.longestStreak, 0);
    });

    test('longest streak handles a month-boundary run within the range', () {
      final stats = StoryStatsService.compute(
        stories: [
          _story(id: 1, year: 2024, month: 6, day: 30),
          _story(id: 2, year: 2024, month: 7, day: 1),
          _story(id: 3, year: 2024, month: 7, day: 2),
        ],
        allTags: [],
        range: StatsRange.year(DateTime(2024, 6, 1)),
        now: DateTime(2024, 7, 2),
      );

      expect(stats.longestStreak, 3);
      expect(stats.currentStreak, 3);
    });
  });

  group('daily word counts', () {
    test('aggregates words per day for goal progress', () {
      final DateTime now = DateTime(2024, 6, 4);
      final stats = StoryStatsService.compute(
        stories: [
          _story(id: 1, year: 2024, month: 6, day: 3, words: 10),
          _story(id: 2, year: 2024, month: 6, day: 3, words: 5),
          _story(id: 3, year: 2024, month: 6, day: 4, words: 7),
        ],
        allTags: [],
        range: StatsRange.month(DateTime(2024, 6, 1)),
        now: now,
      );

      // Per-day words must sum to the total word count, keyed by date-only.
      expect(
        stats.dailyWordCounts.values.fold<int>(0, (a, b) => a + b),
        stats.wordCount,
      );
      expect(
        stats.dailyWordCounts.keys.every((d) => d.hour == 0 && d.minute == 0),
        isTrue,
      );
      expect(
        WritingGoalService.todayWords(stats.dailyWordCounts, now),
        stats.dailyWordCounts[DateTime(now.year, now.month, now.day)],
      );
    });

    test('todayWords is 0 when nothing was written today', () {
      expect(WritingGoalService.todayWords({}, DateTime(2024, 6, 4)), 0);
    });
  });

  group('JournalingPromptsService', () {
    test('same date always returns the same prompt', () {
      final DateTime date = DateTime(2026, 9, 22);
      expect(
        JournalingPromptsService.promptFor(date),
        JournalingPromptsService.promptFor(date),
      );
    });

    test('prompt wraps around the list without going out of bounds', () {
      final prompts = <String>{};
      for (int day = 0; day < 400; day++) {
        prompts.add(
          JournalingPromptsService.promptFor(
            DateTime(2026).add(Duration(days: day)),
          ),
        );
      }
      expect(prompts.length, JournalingPromptsService.all.length);
    });

    test('prompts are non-empty', () {
      for (int day = 0; day < 60; day++) {
        expect(
          JournalingPromptsService.promptFor(
            DateTime(2026, 1, 1).add(Duration(days: day)),
          ),
          isNotEmpty,
        );
      }
    });
  });
}
