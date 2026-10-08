package com.vocechat.vocechat_client

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Starts web links without depending on a plugin's foreground Activity binding.
 * The owner keeps this bridge for the lifetime of its Flutter engine.
 */
internal class ExternalLinkLauncher(context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {
    private val applicationContext = context.applicationContext
    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "openUrl") {
            result.notImplemented()
            return
        }
        val url = (call.arguments as? Map<*, *>)?.get("url") as? String
        val uri = url?.let { Uri.parse(it).normalizeScheme() }
        if (uri == null ||
            uri.scheme !in setOf("http", "https") ||
            uri.host.isNullOrEmpty()
        ) {
            result.error("invalid_url", "A web URL with a host is required.", null)
            return
        }
        val intent = Intent(Intent.ACTION_VIEW, uri)
            .addCategory(Intent.CATEGORY_BROWSABLE)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            // Starting an Activity directly needs neither package-visibility
            // queries nor a runtime permission. NEW_TASK supports app context.
            applicationContext.startActivity(intent)
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            Log.w(TAG, "External browser launch failed: no handler")
            result.error("no_browser", "No application can open this web link.", null)
        } catch (error: Exception) {
            // Native exceptions can include the complete URL, including tokens.
            Log.w(TAG, "External browser launch failed: ${error.javaClass.simpleName}")
            result.error("open_failed", "Android could not open this web link.", null)
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    companion object {
        const val CHANNEL = "vocechat/external_links"
        private const val TAG = "VoceExternalLinks"
    }
}
