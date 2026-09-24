import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/smart_title_suggestion_service.dart';

void main() {
  group('SmartTitleSuggestionService.suggest', () {
    test('returns null for empty or whitespace-only body', () {
      expect(SmartTitleSuggestionService.suggest(bodyPlainText: ''), isNull);
      expect(
        SmartTitleSuggestionService.suggest(bodyPlainText: '   \n  \n'),
        isNull,
      );
    });

    test('returns null when body is too short to make a title', () {
      expect(SmartTitleSuggestionService.suggest(bodyPlainText: 'Hi'), isNull);
      expect(
        SmartTitleSuggestionService.suggest(
          bodyPlainText: 'Ok\nLonger second line here',
        ),
        isNull,
      );
    });

    test('uses the first non-empty line', () {
      final result = SmartTitleSuggestionService.suggest(
        bodyPlainText: '\n  \nTrip to the coast\nOther line',
      );
      expect(result, 'Trip to the coast');
    });

    test('strips markdown headings, bullets, quotes and emphasis', () {
      expect(
        SmartTitleSuggestionService.suggest(
          bodyPlainText: '## Trip to the coast',
        ),
        'Trip to the coast',
      );
      expect(
        SmartTitleSuggestionService.suggest(
          bodyPlainText: '- Trip to the coast',
        ),
        'Trip to the coast',
      );
      expect(
        SmartTitleSuggestionService.suggest(
          bodyPlainText: '> Trip to the coast',
        ),
        'Trip to the coast',
      );
      expect(
        SmartTitleSuggestionService.suggest(
          bodyPlainText: '*Trip* to the coast',
        ),
        'Trip to the coast',
      );
      expect(
        SmartTitleSuggestionService.suggest(
          bodyPlainText: '1. Trip to the coast',
        ),
        'Trip to the coast',
      );
    });

    test('collapses internal whitespace', () {
      expect(
        SmartTitleSuggestionService.suggest(
          bodyPlainText: 'Trip   to\tthe   coast',
        ),
        'Trip to the coast',
      );
    });

    test('capitalizes the first letter', () {
      expect(
        SmartTitleSuggestionService.suggest(bodyPlainText: 'trip to the coast'),
        'Trip to the coast',
      );
    });

    test('keeps short lines as-is', () {
      expect(
        SmartTitleSuggestionService.suggest(
          bodyPlainText: 'A perfect day at the lake',
        ),
        'A perfect day at the lake',
      );
    });

    test('truncates long lines at a sentence boundary when reasonable', () {
      final result = SmartTitleSuggestionService.suggest(
        bodyPlainText:
            'We finally visited the old lighthouse. It was taller than remembered.',
      );
      expect(result, 'We finally visited the old lighthouse.');
    });

    test('truncates long lines at a word boundary with ellipsis otherwise', () {
      final result = SmartTitleSuggestionService.suggest(
        bodyPlainText:
            'A very long rambling opening line about nothing in particular at all really',
        maxChars: 30,
      );
      expect(result, endsWith('…'));
      expect(result!.length, lessThanOrEqualTo(31));
      expect(result.contains(' …'), isFalse);
    });

    test('never cuts mid-word even for a very long first word', () {
      final result = SmartTitleSuggestionService.suggest(
        bodyPlainText:
            'Supercalifragilisticexpialidociousandthensomemorelettershere',
        maxChars: 20,
      );
      expect(result, isNotNull);
      expect(result, endsWith('…'));
    });

    test('returns null when suggestion equals the current title', () {
      expect(
        SmartTitleSuggestionService.suggest(
          bodyPlainText: 'Trip to the coast',
          currentTitle: 'Trip to the coast',
        ),
        isNull,
      );
      expect(
        SmartTitleSuggestionService.suggest(
          bodyPlainText: 'Trip to the coast',
          currentTitle: '  trip to the coast ',
        ),
        isNull,
      );
    });

    test('still suggests when current title differs', () {
      expect(
        SmartTitleSuggestionService.suggest(
          bodyPlainText: 'Trip to the coast',
          currentTitle: 'Untitled',
        ),
        'Trip to the coast',
      );
    });
  });
}
