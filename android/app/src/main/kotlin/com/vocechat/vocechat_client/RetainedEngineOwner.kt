package com.vocechat.vocechat_client

/** Main-thread ownership of a resource that may outlive its Activity.
 *
 * Claim before attaching the new Activity: Flutter can synchronously evict the
 * old one during attachment. A later release from that old Activity must never
 * release the new owner's engine. Identity, rather than equality, is required.
 */
internal class RetainedEngineOwner<Engine : Any, Owner : Any>(
    private val dispose: (Engine) -> Unit,
) {
    var engine: Engine? = null
        private set
    private var owner: Owner? = null

    fun acquire(owner: Owner, create: () -> Engine): Engine {
        val current = engine ?: create().also { engine = it }
        this.owner = owner
        return current
    }

    fun isOwner(owner: Owner): Boolean = this.owner === owner

    fun release(owner: Owner, retain: Boolean) {
        if (!isOwner(owner)) return
        this.owner = null
        if (!retain) releaseIfUnowned()
    }

    fun releaseIfUnowned() {
        if (owner != null) return
        val released = engine ?: return
        engine = null
        dispose(released)
    }
}
