package com.huy.myfinance

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.widget.RemoteViews

/**
 * Home-screen widget with three quick-add buttons.
 * Each button fires an Intent that opens MainActivity with an extras key
 * that Flutter reads via home_widget to jump directly to the Quick Add form.
 */
class WidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { id ->
            updateWidget(context, appWidgetManager, id)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.myfinance_widget)

        views.setOnClickPendingIntent(
            R.id.btn_spending,
            buildPendingIntent(context, widgetId, "spending", 0)
        )
        views.setOnClickPendingIntent(
            R.id.btn_earning,
            buildPendingIntent(context, widgetId, "earning", 1)
        )
        views.setOnClickPendingIntent(
            R.id.btn_transfer,
            buildPendingIntent(context, widgetId, "transfer", 2)
        )

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun buildPendingIntent(
        context: Context,
        widgetId: Int,
        txType: String,
        requestCode: Int
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = "MYFINANCE_QUICK_ADD"
            putExtra("txType", txType)
            putExtra("widgetId", widgetId)
            // Ensure a distinct back-stack so Back exits to the launcher.
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            widgetId * 10 + requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
