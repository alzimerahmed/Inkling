import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/import/day_one_import_parser.dart';

const String _dayOneJson = '''
[
  {
    "creationDate": "2023-01-02T10:30:00Z",
    "text": "First entry body\\nSecond line",
    "tags": ["work", "trip"],
    "mood": "Happy",
    "photos": [
      { "identifier": "IMG_001", "fileName": "IMG_001.jpg" }
    ]
  },
  {
    "creationDate": "2023-02-03T08:00:00Z",
    "text": "Second entry"
  },
  { "creationDate": "not-a-date", "text": "bad date" },
  { "creationDate": "2023-03-01T00:00:00Z", "text": "   " }
]
''';

const String _dayOneEntriesObjectJson = '''
{ "entries": [
  { "creationDate": "2023-05-05T12:00:00Z", "text": "Wrapped entries" }
] }
''';

void main() {
  group('DayOneImportParser.parseJson', () {
    test('parses entries with tags, mood and photos', () {
      final result = DayOneImportParser.parseJson(_dayOneJson);

      expect(result.drafts.length, 2);
      expect(result.skippedCount, 2);

      final first = result.drafts.first;
      expect(first.date.toUtc().hour, 10);
      expect(first.body, contains('First entry body'));
      expect(first.tags, ['work', 'trip']);
      expect(first.feeling, 'Happy');
      expect(first.photoFileNames, ['IMG_001.jpg']);
    });

    test('supports the { entries: [...] } wrapper', () {
      final result = DayOneImportParser.parseJson(_dayOneEntriesObjectJson);
      expect(result.drafts.length, 1);
      expect(result.drafts.first.body, 'Wrapped entries');
    });

    test('rejects invalid JSON', () {
      final result = DayOneImportParser.parseJson('not json');
      expect(result.drafts, isEmpty);
      expect(result.skippedCount, 1);
    });
  });
}
