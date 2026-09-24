import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/views/settings/sync/sync_view_model.dart';

void main() {
  group('SyncViewModel guards', () {
    test('normalizeServerUrl trims whitespace and trailing slashes', () {
      expect(
        SyncViewModel.normalizeServerUrl('  https://cloud.example.com//  '),
        'https://cloud.example.com',
      );
      expect(
        SyncViewModel.normalizeServerUrl('https://x.dev'),
        'https://x.dev',
      );
    });

    test('isServerUrlSecure requires https except localhost loopback', () {
      expect(
        SyncViewModel.isServerUrlSecure('https://cloud.example.com'),
        isTrue,
      );
      expect(
        SyncViewModel.isServerUrlSecure('http://cloud.example.com'),
        isFalse,
      );
      expect(
        SyncViewModel.isServerUrlSecure('ftp://cloud.example.com'),
        isFalse,
      );
      expect(SyncViewModel.isServerUrlSecure('not a url'), isFalse);
      expect(SyncViewModel.isServerUrlSecure('http://localhost:8080'), isTrue);
      expect(SyncViewModel.isServerUrlSecure('http://127.0.0.1:8080'), isTrue);
    });

    test('isPassphraseAcceptable enforces a minimum length of 8', () {
      expect(SyncViewModel.isPassphraseAcceptable('short'), isFalse);
      expect(SyncViewModel.isPassphraseAcceptable('12345678'), isTrue);
      expect(SyncViewModel.isPassphraseAcceptable('a long passphrase'), isTrue);
      expect(SyncViewModel.isPassphraseAcceptable(''), isFalse);
    });
  });
}
