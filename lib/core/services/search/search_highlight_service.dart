/// Splits a search query into highlightable terms and finds their
/// case-insensitive matches in a text body.
///
/// Pure logic — used by `SpHighlightedText` to render match highlighting in
/// search results and unit-tested directly.
class SearchHighlightService {
  /// Terms are split on whitespace; anything shorter than 2 characters is
  /// ignored (single letters would highlight half the page).
  static List<String> terms(String? query) {
    if (query == null) return const [];
    return query.trim().split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
  }

  /// Returns the [text] split into segments; segments with
  /// `isMatch == true` should be rendered highlighted.
  static List<({String text, bool isMatch})> segments(String text, String? query) {
    final queryTerms = terms(query);
    if (queryTerms.isEmpty) return [(text: text, isMatch: false)];

    final matches = <({int start, int end})>[];
    for (final term in queryTerms) {
      final escaped = RegExp.escape(term);
      final regex = RegExp(escaped, caseSensitive: false);
      for (final match in regex.allMatches(text)) {
        matches.add((start: match.start, end: match.end));
      }
    }
    if (matches.isEmpty) return [(text: text, isMatch: false)];

    // Merge overlapping/adjacent matches (multi-term hits can overlap).
    matches.sort((a, b) => a.start.compareTo(b.start));
    final merged = <({int start, int end})>[matches.first];
    for (final m in matches.skip(1)) {
      final last = merged.last;
      if (m.start <= last.end) {
        if (m.end > last.end) merged[merged.length - 1] = (start: last.start, end: m.end);
      } else {
        merged.add(m);
      }
    }

    final segments = <({String text, bool isMatch})>[];
    int cursor = 0;
    for (final m in merged) {
      if (m.start > cursor) segments.add((text: text.substring(cursor, m.start), isMatch: false));
      segments.add((text: text.substring(m.start, m.end), isMatch: true));
      cursor = m.end;
    }
    if (cursor < text.length) segments.add((text: text.substring(cursor), isMatch: false));
    return segments;
  }
}
