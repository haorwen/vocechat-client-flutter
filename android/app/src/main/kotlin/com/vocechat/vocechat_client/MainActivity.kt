package com.vocechat.vocechat_client

import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.agora.agora_rtc_ng.AgoraPIPFlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AgoraPIPFlutterActivity() {
    companion object {
        @Volatile var foreground = false
        private var secureStorageCommit: SecureStorageCommit? = null
        private var backgroundBridge: BackgroundMessageBridge? = null

        fun releaseBackgroundEngine() {
            secureStorageCommit?.dispose()
            secureStorageCommit = null
            backgroundBridge = null
            val engine = BackgroundMessageService.engine
            BackgroundMessageService.engine = null
            engine?.destroy()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        BackgroundMessageService.activityAttached = true
        super.onCreate(savedInstanceState)
        backgroundBridge?.notificationTap(intent)
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine? = BackgroundMessageService.engine

    override fun shouldDestroyEngineWithHost(): Boolean = !BackgroundMessageService.running

    override fun onResume() {
        super.onResume()
        foreground = true
    }

    override fun onPause() {
        foreground = false
        super.onPause()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        backgroundBridge?.notificationTap(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        BackgroundMessageService.activityAttached = false
        if (!BackgroundMessageService.running) {
            BackgroundMessageService.engine = null
            backgroundBridge = null
        }
    }

    private var updater: AndroidUpdateInstaller? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        BackgroundMessageService.engine = flutterEngine
        if (backgroundBridge == null) {
            backgroundBridge = BackgroundMessageBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        }
        if (secureStorageCommit == null) secureStorageCommit = SecureStorageCommit(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        updater = AndroidUpdateInstaller(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        if (!BackgroundMessageService.running) {
            secureStorageCommit?.dispose()
            secureStorageCommit = null
        }
        updater?.dispose()
        updater = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
