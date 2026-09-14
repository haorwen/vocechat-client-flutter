package com.vocechat.vocechat_client

import android.app.Activity
import android.app.DownloadManager
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/** DownloadManager owns transfers across activity/process restarts. Only an
 * explicit foreground Flutter request opens settings or the system installer. */
class AndroidUpdateInstaller(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "vocechat/android_update")
    private val downloads = activity.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    private val prefs = activity.getSharedPreferences("android_apk_download", Context.MODE_PRIVATE)
    private val worker = Executors.newSingleThreadExecutor()

    init {
        channel.setMethodCallHandler { call, result ->
            worker.execute {
                try {
                    val code = call.argument<Number>("version_code")?.toLong() ?: 0L
                    require(code in 1..2100000000L) { "Invalid version code" }
                    when (call.method) {
                        "status" -> reply(result, status(code))
                        "start" -> {
                            val url = call.argument<String>("url") ?: ""
                            val uri = Uri.parse(url)
                            require(uri.scheme == "https" && !uri.host.isNullOrEmpty() && uri.userInfo == null)
                            val existing = status(code)
                            if (prefs.getString("url", null) == url && existing["state"] in listOf("downloading", "ready")) {
                                reply(result, existing)
                            } else {
                                clear()
                                val directory = File(activity.getExternalFilesDir(null)
                                    ?: throw IllegalStateException("Storage unavailable"), "updates")
                                check(directory.exists() || directory.mkdirs())
                                directory.listFiles()?.forEach { it.delete() }
                                // The URL may be extensionless, signed, or end in .bin.
                                // Keep the request URI intact and always use a local
                                // .apk filename, regardless of Content-Disposition.
                                val target = File(directory, "${UUID.randomUUID()}.apk")
                                val request = DownloadManager.Request(uri)
                                    .setTitle("VoceChat update")
                                    .setMimeType("application/vnd.android.package-archive")
                                    .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                                    .setDestinationUri(Uri.fromFile(target))
                                // No chat API keys, cookies, or administrator tokens.
                                val id = downloads.enqueue(request)
                                if (!prefs.edit().putLong("id", id).putLong("code", code)
                                        .putString("url", url).putString("path", target.absolutePath).commit()) {
                                    downloads.remove(id)
                                    throw IllegalStateException("Unable to persist download")
                                }
                                reply(result, status(code))
                            }
                        }
                        "cancel" -> {
                            if (prefs.getLong("code", 0) == code) clear()
                            reply(result, null)
                        }
                        "install" -> install(code, result)
                        "permission" -> activity.runOnUiThread {
                            try {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                        Uri.parse("package:${activity.packageName}")))
                                }
                                result.success(null)
                            } catch (e: Exception) { result.error("permission_failed", e.message, null) }
                        }
                        else -> activity.runOnUiThread { result.notImplemented() }
                    }
                } catch (e: Exception) {
                    activity.runOnUiThread { result.error("update_failed", e.message, null) }
                }
            }
        }
    }

    private fun status(code: Long): Map<String, Any> {
        if (prefs.getLong("code", 0) != code) {
            // Old APKs/downloads are no longer useful after upgrading or a new release.
            if (prefs.contains("id")) clear()
            return mapOf("state" to "idle")
        }
        val id = prefs.getLong("id", -1)
        downloads.query(DownloadManager.Query().setFilterById(id)).use { cursor ->
            if (cursor == null || !cursor.moveToFirst()) return mapOf("state" to "idle")
            val state = when (cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))) {
                DownloadManager.STATUS_SUCCESSFUL -> if (apkFile()?.isFile == true) "ready" else "failed"
                DownloadManager.STATUS_FAILED -> "failed"
                else -> "downloading"
            }
            return mapOf("state" to state,
                "received" to cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)),
                "total" to cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)))
        }
    }

    private fun apkFile(): File? {
        val root = activity.getExternalFilesDir(null) ?: return null
        val path = prefs.getString("path", null) ?: return null
        val file = File(path).canonicalFile
        return file.takeIf { it.parentFile == File(root, "updates").canonicalFile && it.extension == "apk" }
    }

    @Suppress("DEPRECATION")
    private fun install(code: Long, result: MethodChannel.Result) {
        check(status(code)["state"] == "ready") { "Download is not complete" }
        val file = apkFile() ?: throw IllegalStateException("APK not found")
        val archive = activity.packageManager.getPackageArchiveInfo(file.absolutePath, 0)
        val archiveCode = archive?.let { if (Build.VERSION.SDK_INT >= 28) it.longVersionCode else it.versionCode.toLong() }
        val installed = activity.packageManager.getPackageInfo(activity.packageName, 0)
        val installedCode = if (Build.VERSION.SDK_INT >= 28) installed.longVersionCode else installed.versionCode.toLong()
        if (archive == null || archive.packageName != activity.packageName || archiveCode != code || code <= installedCode) {
            clear()
            reply(result, "invalid_apk")
            return
        }
        // Android's package installer verifies signing certificates and platform
        // compatibility, including legitimate signing-key rotation.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !activity.packageManager.canRequestPackageInstalls()) {
            reply(result, "permission_required")
            return
        }
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.update-files", file)
        activity.runOnUiThread {
            try {
                activity.startActivity(Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    clipData = ClipData.newRawUri("VoceChat APK", uri)
                })
                result.success("opened")
            } catch (e: Exception) { result.error("install_failed", e.message, null) }
        }
    }

    private fun clear() {
        val id = prefs.getLong("id", -1)
        if (id != -1L) downloads.remove(id)
        apkFile()?.delete()
        check(prefs.edit().clear().commit()) { "Unable to clear download" }
    }

    private fun reply(result: MethodChannel.Result, value: Any?) =
        activity.runOnUiThread { result.success(value) }

    fun dispose() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
