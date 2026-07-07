package com.huy.myfinance

import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import com.huy.myfinance.pigeon.CaptureHostApi
import com.huy.myfinance.pigeon.RawCaptureMessage

/**
 * Implements the Pigeon [CaptureHostApi] interface, registered in
 * [MainActivity.configureFlutterEngine].
 *
 * All buffer operations delegate to [CaptureBuffer], which owns the single
 * shared lock. This keeps append (Binder thread) and drain/clear (platform
 * thread) mutually exclusive.
 */
class CaptureHostApiImpl(private val context: Context) : CaptureHostApi {

    override fun setWatchedPackages(packages: List<String>) {
        CaptureBuffer.setWatchedPackages(context, packages)
    }

    override fun drainCaptures(): List<RawCaptureMessage> {
        val arr = CaptureBuffer.drain(context)
        return (0 until arr.length()).map { i ->
            val obj = arr.getJSONObject(i)
            RawCaptureMessage(
                id = obj.getString("id"),
                packageName = obj.getString("pkg"),
                title = if (obj.has("title")) obj.getString("title") else null,
                text = obj.getString("text"),
                postTimeMillis = obj.getLong("postTimeMs"),
            )
        }
    }

    override fun clearCaptures(ids: List<String>) {
        CaptureBuffer.clearByIds(context, ids.toSet())
    }

    override fun seenPackages(): List<String> =
        CaptureBuffer.seenPackages(context)

    override fun isListenerEnabled(): Boolean {
        val cn = ComponentName(context, BankCaptureService::class.java)
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager
        return nm.isNotificationListenerAccessGranted(cn)
    }

    override fun openListenerSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // API 30+: jump directly to this app's listener entry.
            val cn = ComponentName(context, BankCaptureService::class.java)
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).apply {
                putExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                    cn.flattenToString())
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        } else {
            // API 29: open the general listener list.
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        }
        context.startActivity(intent)
    }
}
