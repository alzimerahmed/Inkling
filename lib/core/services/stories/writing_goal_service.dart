import 'package:storypad/core/storages/daily_writing_goal_storage.dart';

/// Daily writing-goal lookup: how many words were written today vs the
/// configured goal. Pure logic + storage read, so the goal progress chip can
/// be computed anywhere without touching preferences plumbing.
class WritingGoalService {
  static final DailyWritingGoalStorage _storage = DailyWritingGoalStorage();

  static Future<int> getGoal() async => await _storage.read() ?? 0;

  static Future<void> setGoal(int goal) async {
    if (goal <= 0) {
      await _storage.remove();
    } else {
      await _storage.write(goal);
    }
  }

  /// Words written today, from stats keyed by date-only [DateTime] (00:00).
  static int todayWords(Map<DateTime, int> dailyWordCounts, DateTime now) {
    return dailyWordCounts[DateTime(now.year, now.month, now.day)] ?? 0;
  }

  /// Goal options offered in the settings picker. 0 = off.
  static List<int> get goalOptions => [0, 100, 250, 500, 750, 1000, 2000];
}
