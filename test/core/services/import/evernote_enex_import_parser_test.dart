import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/import/evernote_enex_import_parser.dart';

const String _enex = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE en-export SYSTEM "http://xml.evernote.com/pub/evernote-export3.dtd">
<en-export exportDate="20240101T000000Z" application="Evernote" version="6.x">
  <note>
    <title>Meeting notes</title>
    <created>20230102T103000Z</created>
    <updated>20230103T103000Z</updated>
    <tag>work</tag>
    <tag>meeting</tag>
    <content><![CDATA[<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd"><en-note><p>Discussed & agreed</p><en-media type="image/png" hash="abc"/></en-note>]]></content>
  </note>
  <note>
    <title>Empty</title>
    <created>20230104T103000Z</created>
    <content><![CDATA[<?xml version="1.0"?><en-note></en-note>]]></content>
  </note>
</en-export>
''';

void main() {
  group('EvernoteEnexImportParser.parse', () {
    test('parses title, date, tags and ENML body', () {
      final result = EvernoteEnexImportParser.parse(_enex);

      expect(result.drafts.length, 2);
      expect(result.skippedCount, 0); // title-only note is kept, not dropped

      final draft = result.drafts.first;
      expect(draft.title, 'Meeting notes');
      expect(draft.date.year, 2023);
      expect(draft.date.month, 1);
      expect(draft.date.day, 2);
      expect(draft.tags, ['work', 'meeting']);
      expect(draft.body, contains('Discussed & agreed'));
      expect(draft.warnings, contains('attachments_skipped'));

      // Title-only note: body falls back to the title instead of being skipped.
      final titleOnly = result.drafts.last;
      expect(titleOnly.title, 'Empty');
      expect(draft.body, isNotEmpty);
    });

    test('rejects non-ENEX content', () {
      final result = EvernoteEnexImportParser.parse('<html></html>');
      expect(result.drafts, isEmpty);
      expect(result.skippedCount, 1);
    });
  });
}
