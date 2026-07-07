package com.huy.myfinance

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONObject
import java.util.UUID

/**
 * Buffers raw bank notifications for deferred Dart processing.
 *
 * Per ADR-0017 (deferred capture): performs NO parsing and NO Drift writes.
 * It only records raw text into [CaptureBuffer]. The Flutter app drains the
 * buffer on start/resume and processes it in Dart.
 *
 * Discovery: every unique package name that posts a notification is
 * recorded in the seen-packages set so the [BankPackages] placeholders
 * can be verified from real device data via the developer settings tile.
 *
 * OEM note: NotificationListenerService is granted special system access
 * and is not subject to OEM battery-optimisation task killers, making the
 * deferred model safe on Vivo/OPPO/Xiaomi skins.
 */
class BankCaptureService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val pkg = sbn.packageName ?: return
        val extras = sbn.notification?.extras ?: return

        // Always record the package name for discovery (no content stored here).
        CaptureBuffer.addSeenPackage(this, pkg)

        // Only buffer full content for watched packages.
        if (pkg !in CaptureBuffer.watchedPackages(this)) return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()

        // Prefer EXTRA_BIG_TEXT — Vivo OriginOS and some OEM skins truncate
        // EXTRA_TEXT before it reaches the listener. EXTRA_BIG_TEXT carries the
        // full body when available.
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))
            ?.toString() ?: return

        val entry = JSONObject().apply {
            put("id", UUID.randomUUID().toString())
            put("pkg", pkg)
            if (title != null) put("title", title)
            put("text", text)
            put("postTimeMs", sbn.postTime)
        }
        CaptureBuffer.append(this, entry)
    }
}
