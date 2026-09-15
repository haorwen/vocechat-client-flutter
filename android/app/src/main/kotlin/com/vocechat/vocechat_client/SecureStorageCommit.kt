package com.vocechat.vocechat_client

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** flutter_secure_storage 9.x completes writes after SharedPreferences.apply().
 * A synchronous commit to the same preferences waits for those pending writes
 * and reports disk failures. Keep this off the UI thread and never copy secrets
 * out of the encrypted preferences. */
class SecureStorageCommit(context: Context, messenger: BinaryMessenger) {
    private val preferences = context.applicationContext.getSharedPreferences(
        "FlutterSecureStorage", Context.MODE_PRIVATE
    )
    // The plugin's legacy Android cipher stores its wrapped AES key here.
    // Persist it too if the plugin fell back from EncryptedSharedPreferences.
    private val keyPreferences = context.applicationContext.getSharedPreferences(
        "FlutterSecureKeyStorage", Context.MODE_PRIVATE
    )
    private val channel = MethodChannel(messenger, "vocechat/secure_storage_commit")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "commit") {
                result.notImplemented()
            } else {
                worker.execute {
                    try {
                        // Android guarantees commit waits for outstanding apply
                        // calls on this SharedPreferences instance to finish.
                        check(keyPreferences.edit().commit()) { "Secure key storage commit failed" }
                        check(preferences.edit().commit()) { "Secure storage commit failed" }
                        main.post { result.success(null) }
                    } catch (error: Exception) {
                        main.post { result.error("secure_storage_commit_failed", error.message, null) }
                    }
                }
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
