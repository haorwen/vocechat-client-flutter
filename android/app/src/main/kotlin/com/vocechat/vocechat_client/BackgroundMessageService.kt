package com.vocechat.vocechat_client

import android.Manifest
import android.app.*
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine

/** The service retains the SAME engine/connection as the UI, never a second login. */
class BackgroundMessageService : Service() {
    companion object {
        const val CHANNEL = "background_connection"
        const val MESSAGES = "background_messages"
        const val ID = 41001
        var running = false
        val engine: FlutterEngine? get() = AppFlutterEngine.engine
    }

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= 26) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(NotificationChannel(CHANNEL,
                getString(R.string.background_channel), NotificationManager.IMPORTANCE_LOW))
            manager.createNotificationChannel(NotificationChannel(MESSAGES,
                getString(R.string.background_messages), NotificationManager.IMPORTANCE_DEFAULT))
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Do not advertise message reception after process death without a live engine.
        if (!BuildConfig.DIRECT_DISTRIBUTION_FEATURES || engine == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        val calling = intent?.getBooleanExtra("calling", false) == true
        val open = PendingIntent.getActivity(this, 0, AppLaunchIntent.create(this),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_background_message)
            .setContentTitle(getString(R.string.background_title))
            .setContentText(getString(if (calling) R.string.background_call else R.string.background_body))
            .setContentIntent(open).setOngoing(true).setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE).setOnlyAlertOnce(true).build()
        var types = if (Build.VERSION.SDK_INT >= 34) ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE else 0
        if (Build.VERSION.SDK_INT >= 30 && calling &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        }
        try {
            if (Build.VERSION.SDK_INT >= 29) startForeground(ID, notification, types)
            else startForeground(ID, notification)
            running = true
        } catch (error: RuntimeException) {
            running = false
            stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        running = false
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE)
        else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        AppFlutterEngine.serviceStopped()
        super.onDestroy()
    }
}
