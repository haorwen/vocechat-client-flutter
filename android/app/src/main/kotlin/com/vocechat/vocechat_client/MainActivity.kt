package com.vocechat.vocechat_client

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.agora.agora_rtc_ng.AgoraPIPFlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AgoraPIPFlutterActivity() {
    companion object {
        @Volatile var foreground = false
        private var foregroundActivity: MainActivity? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (BuildConfig.DIRECT_DISTRIBUTION_FEATURES) AppFlutterEngine.notificationTap(intent)
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine? =
        if (BuildConfig.DIRECT_DISTRIBUTION_FEATURES) AppFlutterEngine.acquire(this) else null

    // The standalone owner releases the engine only after its actual Activity
    // detaches and no service needs it. Flutter must not destroy it on eviction.
    override fun shouldDestroyEngineWithHost(): Boolean =
        !BuildConfig.DIRECT_DISTRIBUTION_FEATURES

    private var engineEvicted = false

    override fun detachFromFlutterEngine() {
        engineEvicted = true
        Log.w("VoceEngineLifecycle", "evicted activity=${System.identityHashCode(this)}; finishing detached window")
        super.detachFromFlutterEngine()
        // A FlutterActivity evicted by another host never reattaches on resume.
        // Do not leave that permanently empty window in either task's history.
        finish()
    }

    override fun onResume() {
        super.onResume()
        if (engineEvicted) {
            finish()
            return
        }
        foregroundActivity = this
        foreground = true
    }

    override fun onPause() {
        clearForeground()
        super.onPause()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (BuildConfig.DIRECT_DISTRIBUTION_FEATURES) AppFlutterEngine.notificationTap(intent)
    }

    override fun onDestroy() {
        clearForeground()
        super.onDestroy()
        if (BuildConfig.DIRECT_DISTRIBUTION_FEATURES) {
            AppFlutterEngine.release(this, isChangingConfigurations)
        }
    }

    private fun clearForeground() {
        if (foregroundActivity === this) {
            foregroundActivity = null
            foreground = false
        }
    }

    private var updater: AndroidUpdateInstaller? = null
    private var secureStorageCommit: SecureStorageCommit? = null
    private var externalLinks: ExternalLinkLauncher? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (BuildConfig.DIRECT_DISTRIBUTION_FEATURES) {
            updater = AndroidUpdateInstaller(this, flutterEngine.dartExecutor.binaryMessenger)
        } else {
            // Play owns its engine here. Standalone registers the same bridge
            // in AppFlutterEngine.Resources for the retained engine's lifetime.
            externalLinks = ExternalLinkLauncher(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
            secureStorageCommit = SecureStorageCommit(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        externalLinks?.dispose()
        externalLinks = null
        secureStorageCommit?.dispose()
        secureStorageCommit = null
        updater?.dispose()
        updater = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
