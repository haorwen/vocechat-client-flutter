package com.vocechat.vocechat_client

import org.junit.Assert.*
import org.junit.Test

class RetainedEngineOwnerTest {
    private class Engine
    // Deliberately value-equal hosts prove releases use Activity identity.
    private data class Host(val task: Int = 1)

    @Test fun evictedActivityCannotDestroyItsReplacementsEngine() {
        val disposed = mutableListOf<Engine>()
        val ownership = RetainedEngineOwner<Engine, Host> { disposed.add(it) }
        val old = Host()
        val current = Host()
        val engine = ownership.acquire(old) { Engine() }

        assertSame(engine, ownership.acquire(current) { error("Unexpected new engine") })
        ownership.release(old, retain = false)
        assertSame(engine, ownership.engine)
        assertTrue(ownership.isOwner(current))
        assertFalse(ownership.isOwner(old))
        assertTrue(disposed.isEmpty())

        // A delayed service stop also must not destroy the replacement's UI.
        ownership.releaseIfUnowned()
        assertSame(engine, ownership.engine)
        ownership.release(current, retain = false)
        assertEquals(listOf(engine), disposed)
        assertNull(ownership.engine)
    }

    @Test fun stoppingServiceWithVisibleOrBackgroundedActivityKeepsItsEngine() {
        val disposed = mutableListOf<Engine>()
        val ownership = RetainedEngineOwner<Engine, Host> { disposed.add(it) }
        val host = Host()
        val engine = ownership.acquire(host) { Engine() }

        // onPause/onStop do not relinquish the Activity's ownership, including
        // while a file picker or camera is covering the Flutter window.
        ownership.releaseIfUnowned()
        assertSame(engine, ownership.engine)
        assertTrue(disposed.isEmpty())
        ownership.release(host, retain = false)
        assertEquals(listOf(engine), disposed)
    }

    @Test fun notificationReopeningDetachedActivityReusesBackgroundEngine() {
        val disposed = mutableListOf<Engine>()
        val ownership = RetainedEngineOwner<Engine, Host> { disposed.add(it) }
        val old = Host()
        val engine = ownership.acquire(old) { Engine() }
        ownership.release(old, retain = true)

        val reopened = Host()
        assertSame(engine, ownership.acquire(reopened) { error("Lost background engine") })
        ownership.release(old, retain = false)
        ownership.releaseIfUnowned()
        assertTrue(disposed.isEmpty())
        assertTrue(ownership.isOwner(reopened))
    }

    @Test fun configurationRecreationKeepsEngineWithoutAService() {
        val disposed = mutableListOf<Engine>()
        val ownership = RetainedEngineOwner<Engine, Host> { disposed.add(it) }
        val old = Host()
        val engine = ownership.acquire(old) { Engine() }
        ownership.release(old, retain = true)
        val recreated = Host()
        assertSame(engine, ownership.acquire(recreated) { error("Lost configuration engine") })
        ownership.release(recreated, retain = false)
        assertEquals(listOf(engine), disposed)
    }

    @Test fun lastServiceStopReleasesDetachedEngineExactlyOnceAndReopenStartsFresh() {
        val disposed = mutableListOf<Engine>()
        val ownership = RetainedEngineOwner<Engine, Host> { disposed.add(it) }
        val old = Host()
        val oldEngine = ownership.acquire(old) { Engine() }
        ownership.release(old, retain = true)
        ownership.releaseIfUnowned()
        ownership.releaseIfUnowned()
        ownership.release(old, retain = false)
        assertEquals(listOf(oldEngine), disposed)
        assertNull(ownership.engine)

        val fresh = ownership.acquire(Host()) { Engine() }
        assertNotSame(oldEngine, fresh)
    }

    @Test fun failedCreationDoesNotRetainAHostOrBlockRetry() {
        val ownership = RetainedEngineOwner<Engine, Host> { error("Nothing to dispose") }
        val failed = Host()
        try {
            ownership.acquire(failed) { throw IllegalStateException("startup failed") }
            fail("Expected creation failure")
        } catch (_: IllegalStateException) {
            assertFalse(ownership.isOwner(failed))
            assertNull(ownership.engine)
        }
        val retry = Host()
        ownership.acquire(retry) { Engine() }
        assertTrue(ownership.isOwner(retry))
    }
}
