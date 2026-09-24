import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/import/daylio_import_parser.dart';

const String _daylioCsv = '''
full_date,date_time,mood_title,mood_emoji,activities,note_title,note
01/02/2023,02/01/2023 10:30,Good,🙂,"work,gym",Morning,Feeling productive today
03/01/2023 08:00,03/01/2023 08:00,average,😐,reading,Evening,Tired but calm
04/01/2023,04/01/2023 09:00,bad,😞,,,
''';

void main() {
  group('DaylioImportParser.parse', () {
    test('maps mood to feeling and activities to tags', () {
      final result = DaylioImportParser.parse(_daylioCsv);

      expect(result.drafts.length, 2);
      expect(result.skippedCount, 1); // row with empty note

      final first = result.drafts.first;
      expect(first.date.day, 2);
      expect(first.date.month, 1);
      expect(first.date.hour, 10);
      expect(first.feeling, 'Good');
      expect(first.tags, containsAll(['work', 'gym']));
      expect(first.body, contains('Morning'));
      expect(first.body, contains('Feeling productive today'));
    });

    test('keeps entries with empty notes as skipped', () {
      final result = DaylioImportParser.parse(_daylioCsv);
      expect(result.skippedCount, 1);
    });

    test('rejects non-Daylio CSV', () {
      final result = DaylioImportParser.parse('a,b,c\n1,2,3');
      expect(result.drafts, isEmpty);
      expect(result.skippedCount, 1);
    });
  });
}
