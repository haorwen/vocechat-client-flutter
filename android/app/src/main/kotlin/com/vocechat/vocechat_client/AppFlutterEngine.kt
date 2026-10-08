package com.vocechat.vocechat_client

import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine

/** Owns the standalone engine; Activity and service callbacks run on main.
 * Play keeps FlutterActivity's normal, Activity-owned engine lifecycle.
 */
internal object AppFlutterEngine {
    private class Resources(context: Context, shellArgs: Array<String>) {
        // Explicitly create an externally owned engine. The default constructor
        // registers plugins; FlutterActivity starts Dart on its first onStart.
        val engine = FlutterEngine(context.applicationContext, shellArgs)
        // This bridge uses application context and follows the shared engine,
        // so replacing or destroying an Activity cannot remove its handler.
        val externalLinks = ExternalLinkLauncher(
            context.applicationContext, engine.dartExecutor.binaryMessenger,
        )
        val secureStorage = SecureStorageCommit(
            context.applicationContext, engine.dartExecutor.binaryMessenger,
        )
        val notifications = BackgroundMessageBridge(
            context.applicationContext, engine.dartExecutor.binaryMessenger,
        )

        fun dispose() {
            Log.i(TAG, "destroy engine=${System.identityHashCode(engine)}")
            notifications.dispose()
            externalLinks.dispose()
            secureStorage.dispose()
            engine.destroy()
        }
    }

    private const val TAG = "VoceEngineLifecycle"
    private val ownership = RetainedEngineOwner<Resources, MainActivity> { it.dispose() }

    val engine: FlutterEngine? get() = ownership.engine?.engine

    fun acquire(activity: MainActivity): FlutterEngine {
        val resources = ownership.acquire(activity) {
            Resources(activity.applicationContext, activity.flutterShellArgs.toArray())
        }
        Log.i(TAG, "attach activity=${System.identityHashCode(activity)} engine=${System.identityHashCode(resources.engine)}")
        return resources.engine
    }

    fun release(activity: MainActivity, changingConfigurations: Boolean) {
        Log.i(TAG, "release activity=${System.identityHashCode(activity)} owner=${ownership.isOwner(activity)} background=${BackgroundMessageService.running}")
        ownership.release(activity, retain = changingConfigurations || BackgroundMessageService.running)
    }

    fun serviceStopped() = ownership.releaseIfUnowned()

    fun notificationTap(intent: Intent?) = ownership.engine?.notifications?.notificationTap(intent)
}
