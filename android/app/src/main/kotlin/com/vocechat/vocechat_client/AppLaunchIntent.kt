package com.vocechat.vocechat_client

import android.content.Context
import android.content.Intent

/** Reuse the chat Activity even while a camera/file picker is above it. */
internal object AppLaunchIntent {
    fun create(context: Context): Intent = Intent(context, MainActivity::class.java)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
}
