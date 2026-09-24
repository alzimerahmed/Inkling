package com.tc.writestory.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import com.tc.writestory.MainActivity
import com.tc.writestory.R

/**
 * Inkling home-screen widget (Phase 3, gap #1).
 *
 * Shows today's journaling status (written / not yet + title + word count)
 * and a quick-capture button that deep-links into the app's new-story flow
 * via `inkling://widget?action=new_story` (handled Dart-side by
 * [HomeWidgetService] -> AppQuickActionsService#handleWidgetLaunch).
 *
 * Data comes from `HomeWidgetPreferences` SharedPreferences, written by the
 * home_widget plugin (HomeWidgetService#updateTodayEntry).
 */
class InklingWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(appWidgetId, buildViews(context))
        }
    }

    private fun buildViews(context: Context): RemoteViews {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val todayExists = prefs.getBoolean("today_exists", false)
        val todayTitle = prefs.getString("today_title", "") ?: ""
        val todayWordCount = prefs.getInt("today_word_count", 0)

        val views = RemoteViews(context.packageName, R.layout.inkling_widget)

        if (todayExists) {
            views.setTextViewText(R.id.widget_today_status, context.getString(R.string.widget_written_today))
            views.setTextViewText(
                R.id.widget_today_detail,
                if (todayTitle.isNotEmpty()) todayTitle else context.getString(R.string.widget_words_suffix, todayWordCount),
            )
        } else {
            views.setTextViewText(R.id.widget_today_status, context.getString(R.string.widget_no_entry_today))
            views.setTextViewText(R.id.widget_today_detail, "")
        }

        // Whole-widget tap: open the app normally.
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        views.setOnClickPendingIntent(
            R.id.widget_root,
            PendingIntent.getActivity(
                context,
                0,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ),
        )

        // Quick capture: deep link into the new-story flow.
        val quickCaptureIntent = Intent(context, MainActivity::class.java).apply {
            data = Uri.parse("inkling://widget?action=new_story")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        views.setOnClickPendingIntent(
            R.id.widget_quick_capture,
            PendingIntent.getActivity(
                context,
                1,
                quickCaptureIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ),
        )

        return views
    }
}
