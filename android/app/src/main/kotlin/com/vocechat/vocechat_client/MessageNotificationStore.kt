package com.vocechat.vocechat_client

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/** Local WebSocket notifications use a durable unique key, including after process death.
 * Never prune by count/high-water mid: delayed/out-of-order messages would re-alert.
 */
class MessageNotificationStore(context: Context) : SQLiteOpenHelper(
    context.applicationContext, "message_notification_receipts.db", null, 1
) {
    companion object {
        const val MAX_AGE_MS = 7L * 24 * 60 * 60 * 1000
        private const val RETENTION_MS = 8L * 24 * 60 * 60 * 1000
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE receipts (session TEXT NOT NULL, mid INTEGER NOT NULL, keep_until INTEGER NOT NULL, PRIMARY KEY(session, mid))")
        db.execSQL("CREATE INDEX receipt_expiry ON receipts(keep_until)")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit

    /** Commit BEFORE notifying: a process crash cannot produce a second alert.
     * A crash in the tiny commit→NotificationManager gap may lose that alert;
     * exactly-once delivery cannot be transactional across SQLite and Android.
     */
    @Synchronized
    fun claim(session: String, mid: Long, createdAt: Long, now: Long): Boolean {
        if (session.isEmpty() || mid <= 0 || createdAt <= 0 ||
            createdAt < now - MAX_AGE_MS || createdAt > now + 5 * 60 * 1000) return false
        val db = writableDatabase
        db.beginTransaction()
        try {
            db.delete("receipts", "keep_until < ?", arrayOf(now.toString()))
            val values = ContentValues().apply {
                put("session", session); put("mid", mid); put("keep_until", now + RETENTION_MS)
            }
            val inserted = db.insertWithOnConflict("receipts", null, values, SQLiteDatabase.CONFLICT_IGNORE) != -1L
            db.setTransactionSuccessful()
            return inserted
        } finally {
            db.endTransaction()
        }
    }
}
