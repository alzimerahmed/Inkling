import 'dart:async';
import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:flutter/material.dart';
import 'package:storypad/core/databases/models/story_db_model.dart';
import 'package:storypad/core/services/app_quick_actions_service.dart';

/// Android home-screen widget (Phase 3, gap #1): quick capture + today's
/// entry status.
///
/// - Data flow: [updateTodayEntry] queries today's stories and pushes
///   `today_exists` / `today_title` / `today_word_count` into the
///   `HomeWidgetPreferences` SharedPreferences the native
///   `InklingWidgetProvider` reads on update.
/// - Quick capture: the widget's button launches the app with
///   `inkling://widget?action=new_story`, handled via
///   [AppQuickActionsService.handleWidgetLaunch] (same new-story flow as
///   home-screen quick actions).
class HomeWidgetService {
  HomeWidgetService._();

  static const String androidProviderName = 'InklingWidgetProvider';

  static bool get supported => Platform.isAndroid || Platform.isIOS;

  static Future<void> initialize({required GlobalKey<NavigatorState> navigatorKey}) async {
    if (!supported) return;

    // Widget tap while the app was fully terminated.
    final Uri? initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (uriIsQuickCapture(initialUri: initialUri)) {
      await AppQuickActionsService.instance.handleWidgetLaunch(initialUri);
    }

    // Widget tap while the app is running in the background.
    HomeWidget.widgetClicked.listen((Uri? uri) {
      if (uriIsQuickCapture(initialUri: uri)) {
        AppQuickActionsService.instance.handleWidgetLaunch(uri);
      }
    });
  }

  static bool uriIsQuickCapture({required Uri? initialUri}) =>
      initialUri?.host == 'widget' && initialUri?.queryParameters['action'] == 'new_story';

  /// Refreshes the widget's "today" snapshot. Called opportunistically on
  /// home navigation (see RootViewModel) — cheap query, no isolate needed.
  static Future<void> updateTodayEntry() async {
    if (!Platform.isAndroid) return;

    try {
      final DateTime now = DateTime.now();
      final stories = await StoryDbModel.db.where(filters: {'year': now.year, 'month': now.month, 'day': now.day});

      final items = stories?.items ?? [];
      final bool exists = items.isNotEmpty;
      final String title = exists ? (items.first.latestContent?.title ?? '').trim() : '';
      final int wordCount = exists ? (items.first.latestContent?.wordCount ?? 0) : 0;

      await HomeWidget.saveWidgetData<bool>('today_exists', exists);
      await HomeWidget.saveWidgetData<String>('today_title', title);
      await HomeWidget.saveWidgetData<int>('today_word_count', wordCount);

      await HomeWidget.updateWidget(name: 'InklingWidgetProvider', androidName: 'InklingWidgetProvider');
    } catch (e) {
      // Widget updates must never break app startup/navigation.
      assert(() {
        // ignore: avoid_print
        print('HomeWidgetService#updateTodayEntry failed: $e');
        return true;
      }());
    }
  }
}
