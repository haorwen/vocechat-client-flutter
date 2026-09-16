package com.vocechat.vocechat_client

import android.app.*
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Uses application context so notification delivery survives Activity destruction. */
class BackgroundMessageBridge(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "chat.voce/background")
    private val prefs = context.getSharedPreferences("background_messages", Context.MODE_PRIVATE)
    private var pendingTap: Map<String, String>? = null
    private var session = ""

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "takeTap" -> { result.success(pendingTap); pendingTap = null }
                    "status" -> {
                        val manager = NotificationManagerCompat.from(context)
                        val channelsEnabled = if (Build.VERSION.SDK_INT >= 26) {
                            listOf(BackgroundMessageService.CHANNEL, BackgroundMessageService.MESSAGES).all {
                                manager.getNotificationChannel(it)?.importance != NotificationManager.IMPORTANCE_NONE
                            }
                        } else true
                        result.success(mapOf(
                            "enabled" to prefs.getBoolean("enabled", false),
                            "running" to BackgroundMessageService.running,
                            "pushEnabled" to prefs.getBoolean("pushEnabled", true),
                            "soundEnabled" to prefs.getBoolean("soundEnabled", true),
                            "mentionsOnly" to prefs.getBoolean("mentionsOnly", false),
                            "notifications" to (manager.areNotificationsEnabled() && channelsEnabled),
                            "batterySettingsVisited" to prefs.getBoolean("batterySettingsVisited", false),
                            "batteryExempt" to (Build.VERSION.SDK_INT < 23 ||
                                context.getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(context.packageName))
                        ))
                    }
                    "notificationPreferences" -> {
                        val editor = prefs.edit()
                        for (key in listOf("pushEnabled", "soundEnabled", "mentionsOnly")) {
                            call.argument<Boolean>(key)?.let { editor.putBoolean(key, it) }
                        }
                        check(editor.commit()) { "Cannot save notification preferences" }
                        if (!prefs.getBoolean("pushEnabled", true)) clearMessages()
                        result.success(null)
                    }
                    "setEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") == true
                        check(prefs.edit().putBoolean("enabled", enabled).commit()) { "Cannot save preference" }
                        if (!enabled) stop()
                        result.success(null)
                    }
                    "sync" -> {
                        val nextSession = call.argument<String>("session") ?: ""
                        if (session != nextSession) {
                            clearMessages()
                            session = nextSession
                        }
                        if (session.isEmpty() || !prefs.getBoolean("enabled", false)) stop()
                        else {
                            val intent = Intent(context, BackgroundMessageService::class.java)
                                .putExtra("calling", call.argument<Boolean>("calling") == true)
                            if (BackgroundMessageService.running) context.startService(intent)
                            else if (call.argument<Boolean>("background") != true) ContextCompat.startForegroundService(context, intent)
                        }
                        result.success(null)
                    }
                    "configureNotifications" -> {
                        MessageNotificationRouter.configure(context, call.argument<String>("session") ?: "",
                            call.argument<List<String>>("muted"))
                        result.success(null)
                    }
                    "notify" -> {
                        val account = call.argument<String>("session") ?: ""
                        val mid = call.argument<Number>("mid")?.toLong() ?: 0L
                        val present = call.argument<Boolean>("present") == true
                        if (present && (!BackgroundMessageService.running || session != account)) {
                            result.success(null)
                        } else {
                            MessageNotificationRouter.deliver(context, MessageNotification(
                                account, mid, call.argument<String>("target") ?: "",
                                call.argument<Number>("createdAt")?.toLong() ?: 0L,
                                call.argument<Number>("expiresAt")?.toLong(),
                                call.argument<String>("title") ?: "VoceChat", call.argument<String>("body") ?: "",
                                call.argument<Boolean>("mentioned") == true),
                                present = present, eligible = call.argument<Boolean>("eligible") == true)
                            result.success(null)
                        }
                    }
                    "batterySettings" -> {
                        // Some OEMs (including Xiaomi) report false even after
                        // unrestricted battery use is enabled. A deliberate tap
                        // is sufficient; persist it even if the settings Intent fails.
                        check(prefs.edit().putBoolean("batterySettingsVisited", true).commit()) {
                            "Cannot save battery settings visit"
                        }
                        open(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                            Uri.parse("package:${context.packageName}")), Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                        result.success(null)
                    }
                    "notificationSettings" -> {
                        val intent = if (Build.VERSION.SDK_INT >= 26) Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName) else appSettings()
                        open(intent, appSettings())
                        result.success(null)
                    }
                    "appSettings" -> { open(appSettings(), appSettings()); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("background_service", error.message, null)
            }
        }
    }

    fun notificationTap(intent: Intent?) {
        val target = intent?.getStringExtra("background_target") ?: return
        val account = intent.getStringExtra("background_session") ?: return
        intent.removeExtra("background_target")
        pendingTap = mapOf("target" to target, "session" to account)
        channel.invokeMethod("notificationTap", null)
    }

    private fun stop() {
        context.stopService(Intent(context, BackgroundMessageService::class.java))
        clearMessages()
    }

    private fun clearMessages() = MessageNotificationRouter.clear(context)

    private fun appSettings() = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))
    private fun open(intent: Intent, fallback: Intent) {
        try { context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
        catch (_: android.content.ActivityNotFoundException) { context.startActivity(fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
    }
}
