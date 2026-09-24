/// Gap #18 "AI features (on-device only)" — v1 slice.
///
/// Suggests an entry title from the first meaningful line of the body using
/// pure-Dart string heuristics. No model, no network, no telemetry: this is a
/// deliberate non-LLM take on "AI features" (see docs/research.md ADR-012).
///
/// Pure and side-effect free so it can be unit-tested in isolation.
class SmartTitleSuggestionService {
  static const int defaultMaxChars = 48;
  static const int _minChars = 4;

  /// Returns a title suggestion derived from [bodyPlainText], or `null` when
  /// nothing useful can be suggested (empty body, too short, or the result
  /// would equal [currentTitle]).
  static String? suggest({
    required String bodyPlainText,
    String? currentTitle,
    int maxChars = defaultMaxChars,
  }) {
    final String line = _firstMeaningfulLine(bodyPlainText);
    if (line.length < _minChars) return null;

    final String title = _truncate(_capitalize(line), maxChars);
    if (title.length < _minChars) return null;
    if (currentTitle != null && title.trim().toLowerCase() == currentTitle.trim().toLowerCase()) {
      return null;
    }

    return title;
  }

  /// First non-empty line, stripped of markdown-ish decoration (headings,
  /// bullets, quotes, emphasis markers) and collapsed whitespace.
  static String _firstMeaningfulLine(String bodyPlainText) {
    for (final String rawLine in bodyPlainText.split('\n')) {
      String line = rawLine.trim();
      if (line.isEmpty) continue;

      // Strip leading markdown markers: "# ", "## ", "- ", "* ", "> ", "1. ".
      line = line.replaceFirst(
        RegExp(r'^\s*(#{1,6}\s+|[-*+]\s+|>\s*|\d+[.)]\s+)'),
        '',
      );

      // Strip surrounding emphasis/quote markers.
      line = line.replaceAll(RegExp(r'[*_~`]+'), '');

      // Collapse internal whitespace runs.
      line = line.replaceAll(RegExp(r'\s+'), ' ').trim();

      if (line.isNotEmpty) return line;
    }
    return '';
  }

  /// Truncates at a sentence boundary inside [maxChars] when that leaves a
  /// reasonably long title, otherwise at the last word boundary, appending an
  /// ellipsis. Never mid-word.
  static String _truncate(String text, int maxChars) {
    if (text.length <= maxChars) return text;

    final String head = text.substring(0, maxChars);

    // Prefer cutting at the last sentence end within the head.
    final RegExpMatch? sentence = RegExp(r'[.!?…]').allMatches(head).lastOrNull;
    if (sentence != null && sentence.end >= 12) {
      return text.substring(0, sentence.end).trim();
    }

    // Otherwise cut at the last space (word boundary).
    final int lastSpace = head.lastIndexOf(' ');
    if (lastSpace >= 12) return '${head.substring(0, lastSpace).trim()}…';

    // Very long first word: hard-cut rather than return nothing.
    return '${head.trim()}…';
  }

  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    final int firstLetter = text.indexOf(RegExp(r'\p{L}', unicode: true));
    if (firstLetter < 0) return text;
    return text.replaceRange(
      firstLetter,
      firstLetter + 1,
      text.substring(firstLetter, firstLetter + 1).toUpperCase(),
    );
  }
}
