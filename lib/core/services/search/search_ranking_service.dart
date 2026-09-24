import 'package:storypad/core/databases/models/story_db_model.dart';

/// Ranks search results for a query: title matches first, then entries with
/// more query-term occurrences in the body, then newest first (the DB's
/// default order) as the tiebreaker.
///
/// Pure logic — unit-tested directly. Applied in Dart after the ObjectBox
/// substring query, which already filtered to matching stories.
class SearchRankingService {
  static void rank(List<StoryDbModel> stories, String? query) {
    final terms =
        query
            ?.trim()
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty)
            .toList() ??
        const [];
    if (terms.isEmpty) return;

    int score(StoryDbModel story) {
      final content = story.draftContent ?? story.latestContent;
      final title = content?.title?.toLowerCase() ?? '';
      final body = content?.plainText?.toLowerCase() ?? '';

      int s = 0;
      for (final term in terms) {
        if (title.contains(term)) s += 100;
        final occurrences = term.allMatches(body).length;
        s += occurrences > 10 ? 10 : occurrences;
      }
      return s;
    }

    stories.sort((a, b) {
      final cmp = score(b).compareTo(score(a));
      if (cmp != 0) return cmp;
      // Tiebreaker: keep the DB's newest-first order stable.
      return b.id.compareTo(a.id);
    });
  }
}
