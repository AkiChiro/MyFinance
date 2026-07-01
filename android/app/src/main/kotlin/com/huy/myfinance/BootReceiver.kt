package com.huy.myfinance

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Re-posts the persistent quick-add notification after device reboot.
 * Uses native Android notification APIs because the Flutter engine is not
 * running at BOOT_COMPLETED time. Once the user opens the app, the Flutter
 * flutter_local_notifications plugin replaces this with the full version
 * (including action buttons).
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // IMPORTANCE_DEFAULT (no sound/vibration) matches the Flutter-side channel
        // and is visible on all OEM skins including Vivo OriginOS.
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Thêm nhanh",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "Nút thêm giao dịch nhanh từ thanh thông báo"
            setSound(null, null)
            enableVibration(false)
            enableLights(false)
        }
        manager.createNotificationChannel(channel)

        val launchIntent =
            context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: return
        val contentIntent = PendingIntent.getActivity(
            context, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notif)
            .setContentTitle("MyFinance")
            .setContentText("Nhấn để ghi giao dịch nhanh")
            .setOngoing(true)
            .setAutoCancel(false)
            .setShowWhen(false)
            .setContentIntent(contentIntent)
            .build()

        manager.notify(NOTIF_ID, notification)
    }

    companion object {
        private const val CHANNEL_ID = "myfinance_quick_add_v2"
        private const val NOTIF_ID = 1
    }
}
