package com.vocechat.vocechat_client

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class AppLaunchIntentTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()

    @Test fun launchReturnsToExistingActivityEvenWithAPickerAboveIt() {
        val intent = AppLaunchIntent.create(context)
        assertEquals(ComponentName(context, MainActivity::class.java), intent.component)
        for (flag in listOf(Intent.FLAG_ACTIVITY_NEW_TASK, Intent.FLAG_ACTIVITY_CLEAR_TOP, Intent.FLAG_ACTIVITY_SINGLE_TOP)) {
            assertEquals(flag, intent.flags and flag)
        }
    }

    @Test fun launcherAndFcmUseSingleTaskAndOnlyAppLinksHandlesDeepLinks() {
        val activity = context.packageManager.getActivityInfo(
            ComponentName(context, MainActivity::class.java), PackageManager.GET_META_DATA,
        )
        assertEquals(ActivityInfo.LAUNCH_SINGLE_TASK, activity.launchMode)
        assertTrue(activity.metaData.containsKey("flutter_deeplinking_enabled"))
        assertFalse(activity.metaData.getBoolean("flutter_deeplinking_enabled"))
    }
}
