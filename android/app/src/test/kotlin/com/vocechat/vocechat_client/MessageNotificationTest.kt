package com.vocechat.vocechat_client

import android.app.NotificationManager
import android.content.Context
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class MessageNotificationTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()
    private fun now() = System.currentTimeMillis()
    private fun sample(mid: Long = 42, session: String = "server::1") =
        MessageNotification(session, mid, "u-2", now(), null, "Alice", "hello")
    private fun prepare() {
        MainActivity.foreground = false
        context.getSharedPreferences("background_messages", Context.MODE_PRIVATE).edit().clear().commit()
        MessageNotificationRouter.configure(context, "server::1", emptyList())
        context.getSystemService(NotificationManager::class.java).cancelAll()
    }

    @Test fun replayAndDismissDoNotResetReceipt() {
        prepare()
        val first = sample(100)
        assertTrue(MessageNotificationRouter.deliver(context, first))
        MessageNotificationRouter.clear(context)
        assertFalse(MessageNotificationRouter.deliver(context, first)) // replay after dismissal
        val next = sample(101)
        assertTrue(MessageNotificationRouter.deliver(context, next))
        assertFalse(MessageNotificationRouter.deliver(context, next)) // repeated delivery
    }

    @Test fun receiptsSurviveReopenAndDoNotUseHighWaterMid() {
        val t = now()
        MessageNotificationStore(context).use {
            assertTrue(it.claim("s::1", 200, t, t))
            assertTrue(it.claim("s::1", 100, t, t)) // out-of-order is independent
        }
        MessageNotificationStore(context).use {
            assertFalse(it.claim("s::1", 200, t, t))
            assertTrue(it.claim("s::2", 200, t, t))
            assertTrue(it.claim("another::1", 200, t, t))
        }
    }

    @Test fun concurrentClaimsHaveExactlyOneWinner() {
        val t = now()
        val gate = CountDownLatch(1)
        val pool = Executors.newFixedThreadPool(2)
        try {
            val claims = (1..2).map { pool.submit<Boolean> {
                gate.await()
                MessageNotificationStore(context).use { it.claim("race::1", 99, t, t) }
            } }
            gate.countDown()
            assertEquals(1, claims.count { it.get() })
        } finally { pool.shutdownNow() }
    }

    @Test fun foregroundFilteredAndExpiredMessagesCannotAlertLater() {
        prepare()
        MainActivity.foreground = true
        val message = sample(301)
        assertFalse(MessageNotificationRouter.deliver(context, message))
        MainActivity.foreground = false
        assertFalse(MessageNotificationRouter.deliver(context, message))
        val muted = sample(302)
        assertFalse(MessageNotificationRouter.deliver(context, muted, eligible = false))
        assertFalse(MessageNotificationRouter.deliver(context, muted))
        assertFalse(MessageNotificationRouter.deliver(context, sample(303).copy(expiresAt = now() - 1)))
    }

    @Test fun accountSwitchDoesNotEraseReceiptsOrAcceptWrongAccount() {
        prepare()
        val message = sample(401)
        assertTrue(MessageNotificationRouter.deliver(context, message))
        MessageNotificationRouter.configure(context, "server::2", emptyList())
        assertFalse(MessageNotificationRouter.deliver(context, sample(402)))
        MessageNotificationRouter.configure(context, "server::1", emptyList())
        assertFalse(MessageNotificationRouter.deliver(context, message))
    }

    @Test fun expiredRetentionCannotResurrectOldTransportMessages() {
        val t = now()
        MessageNotificationStore(context).use {
            assertTrue(it.claim("ttl::1", 42, t, t))
            val later = t + 9L * 24 * 60 * 60 * 1000
            assertTrue(it.claim("ttl::1", 43, later, later)) // triggers cleanup
            assertFalse(it.claim("ttl::1", 42, t, later))
        }
    }

}
