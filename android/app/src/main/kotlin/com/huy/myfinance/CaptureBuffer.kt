package com.huy.myfinance

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * Single point of control for the native notification-capture buffer.
 *
 * All reads and writes go through one [lock] so [BankCaptureService.onNotificationPosted]
 * (Binder thread) and the Pigeon host methods (main/platform thread) never race.
 * All SharedPreferences writes use .commit() (synchronous) inside the lock so the
 * write completes before the lock is released.
 */
object CaptureBuffer {

    private const val PREFS_NAME = "myfinance_captures"
    private const val KEY_BUFFER = "capture_buffer"
    private const val KEY_WATCHED = "watched_packages"
    private const val KEY_SEEN = "seen_packages"

    private val lock = Any()

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** Appends a capture entry to the buffer. */
    fun append(context: Context, entry: JSONObject) {
        synchronized(lock) {
            val p = prefs(context)
            val arr = JSONArray(p.getString(KEY_BUFFER, "[]") ?: "[]")
            arr.put(entry)
            p.edit().putString(KEY_BUFFER, arr.toString()).commit()
        }
    }

    /**
     * Returns a snapshot of all buffered captures without modifying the buffer.
     * Call [clearByIds] after processing the returned snapshot.
     */
    fun drain(context: Context): JSONArray {
        synchronized(lock) {
            return JSONArray(prefs(context).getString(KEY_BUFFER, "[]") ?: "[]")
        }
    }

    /**
     * Removes only the entries whose "id" field is in [ids].
     * Never blanket-overwrites the buffer so notifications that arrived during
     * the drain window are preserved.
     */
    fun clearByIds(context: Context, ids: Set<String>) {
        if (ids.isEmpty()) return
        synchronized(lock) {
            val p = prefs(context)
            val arr = JSONArray(p.getString(KEY_BUFFER, "[]") ?: "[]")
            val kept = JSONArray()
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                if (obj.getString("id") !in ids) kept.put(obj)
            }
            p.edit().putString(KEY_BUFFER, kept.toString()).commit()
        }
    }

    /** Replaces the watched-packages set. */
    fun setWatchedPackages(context: Context, packages: List<String>) {
        synchronized(lock) {
            prefs(context).edit()
                .putString(KEY_WATCHED, JSONArray(packages).toString())
                .commit()
        }
    }

    /** Returns the current watched-packages set. */
    fun watchedPackages(context: Context): Set<String> {
        synchronized(lock) {
            val raw = prefs(context).getString(KEY_WATCHED, "[]") ?: "[]"
            val arr = JSONArray(raw)
            return (0 until arr.length()).mapTo(mutableSetOf()) { arr.getString(it) }
        }
    }

    /** Records a package name as seen (discovery; no notification content). */
    fun addSeenPackage(context: Context, packageName: String) {
        synchronized(lock) {
            val p = prefs(context)
            val raw = p.getString(KEY_SEEN, "[]") ?: "[]"
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                if (arr.getString(i) == packageName) return
            }
            arr.put(packageName)
            p.edit().putString(KEY_SEEN, arr.toString()).commit()
        }
    }

    /** Returns all package names that have posted a notification. */
    fun seenPackages(context: Context): List<String> {
        synchronized(lock) {
            val raw = prefs(context).getString(KEY_SEEN, "[]") ?: "[]"
            val arr = JSONArray(raw)
            return (0 until arr.length()).map { arr.getString(it) }
        }
    }
}
