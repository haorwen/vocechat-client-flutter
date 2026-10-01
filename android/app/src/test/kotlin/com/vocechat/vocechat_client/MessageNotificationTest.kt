package com.vocechat.vocechat_client

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import org.junit.Assert.*
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.SQLiteMode
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
// Android's native SQLite waits for a competing transaction; the legacy
// sqlite4java shadow rejects concurrent BEGIN immediately instead.
@SQLiteMode(SQLiteMode.Mode.NATIVE)
class MessageNotificationTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()

    @Before fun resetConnections() {
        MessageNotificationRouter.closeStore()
        MainActivity.foreground = false
    }

    @After fun closeConnections() {
        // Robolectric replaces SQLite connections between test environments;
        // a Kotlin object's cached helper must not survive that reset.
        MessageNotificationRouter.closeStore()
        MainActivity.foreground = false
    }

    private fun <T> withStore(block: (MessageNotificationStore) -> T): T {
        val store = MessageNotificationStore(context)
        try {
            return block(store)
        } finally {
            // SQLiteOpenHelper did not implement AutoCloseable on API 28.
            // Compiling .use against a newer SDK otherwise adds an invalid cast.
            store.close()
        }
    }

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
        withStore {
            assertTrue(it.claim("s::1", 200, t, t))
            assertTrue(it.claim("s::1", 100, t, t)) // out-of-order is independent
        }
        withStore {
            assertFalse(it.claim("s::1", 200, t, t))
            assertTrue(it.claim("s::2", 200, t, t))
            assertTrue(it.claim("another::1", 200, t, t))
        }
    }

    @Test fun concurrentClaimsHaveExactlyOneWinner() {
        val t = now()
        val gate = CountDownLatch(1)
        val pool = Executors.newFixedThreadPool(2)
        val stores = List(2) { MessageNotificationStore(context) }
        try {
            // API 28's Robolectric SQLite shadow cannot initialize two
            // android_metadata tables concurrently. Open independent helpers
            // first, then race the actual receipt inserts on their connections.
            stores.forEach { it.writableDatabase }
            val claims = stores.map { store -> pool.submit<Boolean> {
                gate.await()
                store.claim("race::1", 99, t, t)
            } }
            gate.countDown()
            assertEquals(1, claims.count { it.get() })
        } finally {
            gate.countDown()
            pool.shutdownNow()
            pool.awaitTermination(5, TimeUnit.SECONDS)
            stores.forEach { it.close() }
        }
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
        withStore {
            assertTrue(it.claim("ttl::1", 42, t, t))
            val later = t + 9L * 24 * 60 * 60 * 1000
            assertTrue(it.claim("ttl::1", 43, later, later)) // triggers cleanup
            assertFalse(it.claim("ttl::1", 42, t, later))
        }
    }

    @Test fun messageTapReusesActivityAndPreservesItsDestination() {
        prepare()
        assertTrue(MessageNotificationRouter.deliver(context, sample(501)))
        val notification = context.getSystemService(NotificationManager::class.java)
            .activeNotifications.single().notification
        val intent = shadowOf(notification.contentIntent).savedIntent
        assertEquals("u-2", intent.getStringExtra("background_target"))
        assertEquals("server::1", intent.getStringExtra("background_session"))
        assertEquals("vocechat-notification", intent.data?.scheme)
        assertEquals(Intent.FLAG_ACTIVITY_CLEAR_TOP, intent.flags and Intent.FLAG_ACTIVITY_CLEAR_TOP)
        assertEquals(Intent.FLAG_ACTIVITY_SINGLE_TOP, intent.flags and Intent.FLAG_ACTIVITY_SINGLE_TOP)
        assertEquals(Intent.FLAG_ACTIVITY_NEW_TASK, intent.flags and Intent.FLAG_ACTIVITY_NEW_TASK)
    }

}
