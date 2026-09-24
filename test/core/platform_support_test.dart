// Gap #16 (web/desktop companion v1): platform-guard regression tests.
//
// These run on the test host (desktop VM), so `Platform.isAndroid`/`isIOS`
// are false and every Android/iOS-only service must degrade to a safe no-op
// rather than throwing. They assert behavior (graceful no-ops, consistent
// support flags), not implementation details.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/constants/app_constants.dart';
import 'package:storypad/core/services/app_quick_actions_service.dart';
import 'package:storypad/core/services/notifications/local_notification_service.dart';
import 'package:storypad/core/services/widgets/home_widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('kSupportDesktop', () {
    test('matches the host Platform exactly', () {
      expect(
        kSupportDesktop,
        Platform.isMacOS || Platform.isLinux || Platform.isWindows,
      );
    });

    test('is false on mobile platforms', () {
      if (Platform.isAndroid || Platform.isIOS) {
        expect(kSupportDesktop, isFalse);
      } else {
        expect(kSupportDesktop, isTrue);
      }
    });
  });

  group('HomeWidgetService (Android/iOS-only home-screen widget)', () {
    test('reports supported only on Android/iOS', () {
      expect(HomeWidgetService.supported, Platform.isAndroid || Platform.isIOS);
    });

    test('is a safe no-op on desktop hosts', () {
      if (Platform.isAndroid || Platform.isIOS) return;
      // Must complete without throwing a MissingPluginException.
      expect(HomeWidgetService.updateTodayEntry(), completes);
    });

    test(
      'uriIsQuickCapture only matches inkling://widget?action=new_story',
      () {
        expect(
          HomeWidgetService.uriIsQuickCapture(
            initialUri: Uri.parse('inkling://widget?action=new_story'),
          ),
          isTrue,
        );
        expect(
          HomeWidgetService.uriIsQuickCapture(
            initialUri: Uri.parse('inkling://widget?action=other'),
          ),
          isFalse,
        );
        expect(
          HomeWidgetService.uriIsQuickCapture(
            initialUri: Uri.parse('inkling://other?action=new_story'),
          ),
          isFalse,
        );
        expect(HomeWidgetService.uriIsQuickCapture(initialUri: null), isFalse);
      },
    );
  });

  group('AppQuickActionsService (Android/iOS-only shortcuts)', () {
    test('reports supported only on Android/iOS', () {
      expect(
        AppQuickActionsService.instance.supported,
        Platform.isAndroid || Platform.isIOS,
      );
    });

    test('setActions is a safe no-op on desktop hosts', () {
      if (AppQuickActionsService.instance.supported) return;
      expect(AppQuickActionsService.instance.setActions(null), completes);
      expect(AppQuickActionsService.instance.setActions([]), completes);
    });

    test('maxActionCount is 0 on unsupported platforms', () {
      if (!AppQuickActionsService.instance.supported) {
        expect(AppQuickActionsService.instance.maxActionCount, 0);
      } else {
        expect(AppQuickActionsService.instance.maxActionCount, greaterThan(0));
      }
    });
  });

  group('LocalNotificationService (reminders)', () {
    test('reports supported only on Android/iOS/macOS', () {
      expect(
        LocalNotificationService.instance.supported,
        Platform.isAndroid || Platform.isIOS || Platform.isMacOS,
      );
    });

    test('requestPermission returns false on unsupported platforms', () {
      if (LocalNotificationService.instance.supported) return;
      expect(
        LocalNotificationService.instance.requestPermission(),
        completion(isFalse),
      );
    });
  });
}
