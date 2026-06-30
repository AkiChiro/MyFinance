package com.huy.myfinance

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

/**
 * Standard FlutterActivity. Flutter plugins (including home_widget) are
 * auto-registered via GeneratedPluginRegistrant — no manual setup needed.
 *
 * On a widget button tap, WidgetProvider fires an intent with action
 * MYFINANCE_QUICK_ADD and extra "txType". We write the value into the
 * SharedPreferences name that home_widget uses on Android ("HomeWidgetPreferences"),
 * then Flutter's HomeWidget.getWidgetData<String>('pendingTxType') picks it up.
 */
class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleWidgetIntent()
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleWidgetIntent()
    }

    private fun handleWidgetIntent() {
        val i = intent ?: return
        if (i.action != "MYFINANCE_QUICK_ADD") return
        val txType = i.getStringExtra("txType") ?: return
        getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            .edit()
            .putString("pendingTxType", txType)
            .apply()
    }
}
