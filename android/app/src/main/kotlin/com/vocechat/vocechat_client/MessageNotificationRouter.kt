package com.vocechat.vocechat_client

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONArray

internal data class MessageNotification(
    val session: String, val mid: Long, val target: String,
    val createdAt: Long, val expiresAt: Long?, val title: String, val body: String,
    val mentioned: Boolean = false
)

/** Local WebSocket notification gate. SQLite enforces a unique receipt even
 * when callers use different helper instances concurrently.
 */
internal object MessageNotificationRouter {
    private var store: MessageNotificationStore? = null
    private fun store(context: Context): MessageNotificationStore = store
        ?: MessageNotificationStore(context).also { store = it }

    @Synchronized
    fun configure(context: Context, session: String, muted: List<String>?) {
        val prefs = context.getSharedPreferences("background_messages", Context.MODE_PRIVATE)
        val changed = prefs.getString("notificationSession", "") != session
        if (changed) clear(context)
        val editor = prefs.edit().putString("notificationSession", session)
        if (muted != null || changed) editor.putString("mutedTargets", JSONArray(muted ?: emptyList<String>()).toString())
        check(editor.commit())
        // Receipts intentionally survive account switches and clearing the shade.
    }

    @Synchronized
    fun deliver(context: Context, message: MessageNotification, present: Boolean = true,
                eligible: Boolean = true): Boolean {
        val prefs = context.getSharedPreferences("background_messages", Context.MODE_PRIVATE)
        if (prefs.getString("notificationSession", "") != message.session) return false
        val now = System.currentTimeMillis()
        val muted = JSONArray(prefs.getString("mutedTargets", "[]"))
        val isMuted = (0 until muted.length()).any { muted.optString(it) == message.target }
        val group = message.target.startsWith("g-")
        val allowed = eligible && prefs.getBoolean("pushEnabled", true) &&
            (!isMuted || (group && message.mentioned)) &&
            (!group || !prefs.getBoolean("mentionsOnly", false) || message.mentioned) &&
            (message.expiresAt == null || message.expiresAt > now)
        val display = present && allowed && !MainActivity.foreground
        val manager = NotificationManagerCompat.from(context)
        ensureChannel(context)
        // A permission failure is retryable: do not consume a display receipt.
        if (display && (!manager.areNotificationsEnabled() ||
            (Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel(BackgroundMessageService.MESSAGES)?.importance == NotificationManager.IMPORTANCE_NONE))) return false
        if (!store(context).claim(message.session, message.mid, message.createdAt, now)) return false
        if (!display) return false // foreground/filtered messages also consume their key

        val tag = "voce-message:${message.session}:${message.target}"
        val intent = Intent(context, MainActivity::class.java)
            .setAction("chat.voce.MESSAGE")
            .setData(Uri.parse("vocechat-notification://open/${Uri.encode(message.session)}/${message.target}"))
            .putExtra("background_target", message.target)
            .putExtra("background_session", message.session)
        val pending = PendingIntent.getActivity(context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(context, BackgroundMessageService.MESSAGES)
            .setSmallIcon(R.drawable.ic_background_message)
            .setContentTitle(message.title.take(120)).setContentText(message.body.take(240))
            .setContentIntent(pending).setAutoCancel(true)
            .setSilent(!prefs.getBoolean("soundEnabled", true))
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setTimeoutAfter(message.expiresAt?.let { (it - now).coerceAtLeast(1) } ?: 0L).build()
        val nativeManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 23) {
            nativeManager.activeNotifications.filter { it.tag?.startsWith("voce-message:") == true && it.tag != tag }
                .sortedByDescending { it.postTime }.drop(23)
                .forEach { nativeManager.cancel(it.tag, it.id) }
        }
        manager.notify(tag, 0, notification)
        return true
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(BackgroundMessageService.MESSAGES,
                    context.getString(R.string.background_messages), NotificationManager.IMPORTANCE_DEFAULT))
        }
    }

    @Synchronized
    fun clear(context: Context) {
        if (Build.VERSION.SDK_INT >= 23) {
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.activeNotifications.filter { it.tag == "voce-background" || it.tag?.startsWith("voce-message:") == true }
                .forEach { manager.cancel(it.tag, it.id) }
        }
    }
}
