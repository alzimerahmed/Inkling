package com.tc.writestory.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import com.tc.writestory.MainActivity

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
 *
 * Resource IDs are resolved by name via [Context.getPackageName] because the
 * app has product flavors with different applicationIds (com.tc.writestory /
 * com.tc.writestory.community), so a compile-time `R` import cannot work for
 * both flavors from a shared source set.
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

    private fun resId(context: Context, name: String, defType: String): Int =
        context.resources.getIdentifier(name, defType, context.packageName)

    private fun string(context: Context, name: String, vararg args: Any): String {
        val id = resId(context, name, "string")
        return if (id != 0) context.getString(id, *args) else ""
    }

    private fun buildViews(context: Context): RemoteViews {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val todayExists = prefs.getBoolean("today_exists", false)
        val todayTitle = prefs.getString("today_title", "") ?: ""
        val todayWordCount = prefs.getInt("today_word_count", 0)

        val views = RemoteViews(context.packageName, resId(context, "inkling_widget", "layout"))
        val statusId = resId(context, "widget_today_status", "id")
        val detailId = resId(context, "widget_today_detail", "id")

        if (todayExists) {
            views.setTextViewText(statusId, string(context, "widget_written_today"))
            views.setTextViewText(
                detailId,
                if (todayTitle.isNotEmpty()) todayTitle else string(context, "widget_words_suffix", todayWordCount),
            )
        } else {
            views.setTextViewText(statusId, string(context, "widget_no_entry_today"))
            views.setTextViewText(detailId, "")
        }

        // Whole-widget tap: open the app normally.
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        views.setOnClickPendingIntent(
            resId(context, "widget_root", "id"),
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
            resId(context, "widget_quick_capture", "id"),
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
