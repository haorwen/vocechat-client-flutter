package com.vocechat.vocechat_client

import android.app.Activity
import android.app.Application
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.FlutterException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowLog
import java.nio.ByteBuffer

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class ExternalLinkLauncherTest {
    private val application: Application get() = RuntimeEnvironment.getApplication()

    @Test fun opensTheDocumentThroughAndroidWithoutAnActivityOrPackageQuery() {
        val messenger = FakeMessenger()
        val bridge = ExternalLinkLauncher(application, messenger)
        try {
            val url = "https://doc.voce.chat/bot/bot-and-webhook?token=abc#example"
            assertEquals(true, messenger.invoke("openUrl", mapOf("url" to url)))

            val intent = checkNotNull(shadowOf(application).nextStartedActivity)
            assertEquals(Intent.ACTION_VIEW, intent.action)
            assertEquals(url, intent.data.toString())
            assertTrue(intent.hasCategory(Intent.CATEGORY_BROWSABLE))
            assertEquals(Intent.FLAG_ACTIVITY_NEW_TASK, intent.flags and Intent.FLAG_ACTIVITY_NEW_TASK)
            assertNull(intent.component)
            assertNull(intent.`package`)
        } finally {
            bridge.dispose()
        }
    }

    @Test fun remainsAvailableWhenItsOriginalActivityIsDestroyed() {
        val controller = Robolectric.buildActivity(Activity::class.java).setup()
        val messenger = FakeMessenger()
        val bridge = ExternalLinkLauncher(controller.get(), messenger)
        controller.pause().stop().destroy()
        try {
            assertEquals(true, messenger.invoke("openUrl", mapOf("url" to "http://example.com/path")))
            val intent = checkNotNull(shadowOf(application).nextStartedActivity)
            assertEquals("http://example.com/path", intent.data.toString())
        } finally {
            bridge.dispose()
        }
        assertFalse(messenger.hasHandler)
    }

    @Test fun acceptsWebSchemesCaseInsensitivelyForAndroidIntentMatching() {
        val messenger = FakeMessenger()
        val bridge = ExternalLinkLauncher(application, messenger)
        try {
            assertEquals(true, messenger.invoke("openUrl", mapOf("url" to "HTTPS://example.com/path")))
            val intent = checkNotNull(shadowOf(application).nextStartedActivity)
            assertEquals("https", intent.data?.scheme)
        } finally {
            bridge.dispose()
        }
    }

    @Test fun rejectsMissingUrlsNonWebSchemesAndUrlsWithoutAHost() {
        val messenger = FakeMessenger()
        val bridge = ExternalLinkLauncher(application, messenger)
        try {
            for (url in listOf(null, 7, "", "https:/relative", "https://", "javascript:alert(1)", "vocechat://open")) {
                val error = assertThrows(FlutterException::class.java) {
                    messenger.invoke("openUrl", mapOf("url" to url))
                }
                assertEquals("invalid_url", error.code)
            }
            assertNull(shadowOf(application).nextStartedActivity)
        } finally {
            bridge.dispose()
        }
    }

    @Test fun reportsUnavailableHandlersWithoutIncludingTheUrl() {
        assertLaunchFailure(ActivityNotFoundException("secret-token-in-url"), "no_browser")
    }

    @Test fun reportsAndroidLaunchErrorsWithoutIncludingTheUrl() {
        assertLaunchFailure(SecurityException("secret-token-in-url"), "open_failed")
    }

    @Test fun leavesOtherMethodsUnimplemented() {
        val messenger = FakeMessenger()
        val bridge = ExternalLinkLauncher(application, messenger)
        try {
            assertNull(messenger.invoke("other", mapOf("url" to "https://example.com")))
            assertNull(shadowOf(application).nextStartedActivity)
        } finally {
            bridge.dispose()
        }
    }

    private fun assertLaunchFailure(failure: RuntimeException, expectedCode: String) {
        val refusingContext = object : ContextWrapper(application) {
            override fun getApplicationContext(): Context = this
            override fun startActivity(intent: Intent) { throw failure }
        }
        val messenger = FakeMessenger()
        val bridge = ExternalLinkLauncher(refusingContext, messenger)
        ShadowLog.clear()
        try {
            val error = assertThrows(FlutterException::class.java) {
                messenger.invoke("openUrl", mapOf("url" to "https://example.com/?secret-token-in-url"))
            }
            assertEquals(expectedCode, error.code)
            assertFalse(error.message.orEmpty().contains("secret-token-in-url"))
            assertTrue(ShadowLog.getLogsForTag("VoceExternalLinks").isNotEmpty())
            assertTrue(ShadowLog.getLogsForTag("VoceExternalLinks").none { it.msg.contains("secret-token-in-url") })
        } finally {
            bridge.dispose()
        }
    }

    private class FakeMessenger : BinaryMessenger {
        private var handler: BinaryMessenger.BinaryMessageHandler? = null
        val hasHandler: Boolean get() = handler != null

        override fun send(channel: String, message: ByteBuffer?) = Unit

        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) = Unit

        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {
            assertEquals("vocechat/external_links", channel)
            this.handler = handler
        }

        fun invoke(method: String, arguments: Any?): Any? {
            val codec = StandardMethodCodec.INSTANCE
            val call = codec.encodeMethodCall(MethodCall(method, arguments))
            call.flip()
            var envelope: ByteBuffer? = null
            var replied = false
            checkNotNull(handler).onMessage(call) { reply ->
                envelope = reply
                replied = true
            }
            check(replied) { "The platform method did not reply" }
            val reply = envelope ?: return null
            reply.flip()
            return codec.decodeEnvelope(reply)
        }
    }
}
