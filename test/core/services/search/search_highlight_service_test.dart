import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/search/search_highlight_service.dart';

void main() {
  group('SearchHighlightService', () {
    test('splits query into terms, ignoring short tokens', () {
      expect(SearchHighlightService.terms('hello  world a'), ['hello', 'world']);
      expect(SearchHighlightService.terms(null), isEmpty);
    });

    test('finds case-insensitive matches', () {
      final segments = SearchHighlightService.segments('Hello World', 'world');
      expect(segments, [
        (text: 'Hello ', isMatch: false),
        (text: 'World', isMatch: true),
      ]);
    });

    test('merges overlapping/adjacent matches', () {
      final segments = SearchHighlightService.segments('abcabc', 'abc abc');
      // Duplicate terms produce adjacent hits (0-3, 3-6) → merged into one.
      expect(segments, [(text: 'abcabc', isMatch: true)]);
    });

    test('returns whole text when no match', () {
      final segments = SearchHighlightService.segments('nothing here', 'xyz');
      expect(segments, [(text: 'nothing here', isMatch: false)]);
    });
  });
}
