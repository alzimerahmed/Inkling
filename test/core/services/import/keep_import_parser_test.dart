import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/import/keep_import_parser.dart';

const String _keepNote = '''
{
  "title": "Groceries",
  "textContent": "milk\\neggs",
  "createdTimestampUtc": "1690000000000",
  "userEditedTimestampUtc": "1690000100000",
  "labels": [ { "name": "food" }, { "name": "home" } ]
}
''';

const String _keepChecklistNote = '''
{
  "title": "Packing",
  "listContent": [
    { "text": "passport", "isChecked": true },
    { "text": "charger", "isChecked": false }
  ],
  "createdTimestampUtc": "1690000000000"
}
''';

void main() {
  group('KeepImportParser.parse', () {
    test('parses title, body and labels', () {
      final draft = KeepImportParser.parse(_keepNote);

      expect(draft, isNotNull);
      expect(draft!.title, 'Groceries');
      expect(draft.body, 'milk\neggs');
      expect(draft.tags, ['food', 'home']);
      expect(draft.date.year, greaterThanOrEqualTo(2023));
    });

    test('flattens checklist notes', () {
      final draft = KeepImportParser.parse(_keepChecklistNote);

      expect(draft, isNotNull);
      expect(draft!.body, contains('[x] passport'));
      expect(draft.body, contains('[ ] charger'));
    });

    test('returns null for invalid JSON', () {
      expect(KeepImportParser.parse('nope'), isNull);
    });
  });
}
