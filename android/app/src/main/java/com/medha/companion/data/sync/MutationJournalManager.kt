package com.medha.companion.data.sync

import android.content.ContentValues
import androidx.sqlite.db.SupportSQLiteDatabase
import com.medha.companion.data.model.SyncChangeLog
import com.medha.companion.data.model.SyncOperation
import java.util.concurrent.atomic.AtomicLong

/**
 * Thread-safe Lamport logical clock for monotonic causality tracking across offline devices.
 */
class LamportClock(initial: Long = 0L) {
    private val clock = AtomicLong(initial)

    fun get(): Long = clock.get()

    fun increment(): Long = clock.incrementAndGet()

    fun update(receivedLamport: Long): Long {
        while (true) {
            val current = clock.get()
            val next = kotlin.math.max(current, receivedLamport) + 1
            if (clock.compareAndSet(current, next)) {
                return next
            }
        }
    }
}

/**
 * Mutation Journal Manager: Change Data Capture (CDC) recording, unpushed query,
 * and compactification routines.
 */
class MutationJournalManager(
    private val db: SupportSQLiteDatabase,
    private val lamportClock: LamportClock = LamportClock()
) {

    /**
     * Appends a local mutation to sync_change_log with an incremented Lamport timestamp.
     */
    fun recordChange(
        entityType: String,
        entityId: String,
        operation: SyncOperation,
        dataJson: String?
    ): Long {
        val lamport = lamportClock.increment()
        val cv = ContentValues().apply {
            put("entityType", entityType)
            put("entityId", entityId)
            put("operation", operation.rawValue)
            put("data", dataJson)
            put("timestamp", System.currentTimeMillis())
            put("lamportClock", lamport)
            put("isSynced", 0)
        }
        return db.insert("sync_change_log", android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE, cv)
    }

    /**
     * Retrieves all unpushed mutations in deterministic ascending log order.
     */
    fun getUnpushedChanges(limit: Int = 100): List<SyncChangeLog> {
        val list = mutableListOf<SyncChangeLog>()
        val sql = "SELECT id, entityType, entityId, operation, data, timestamp, lamportClock, isSynced FROM sync_change_log WHERE isSynced = 0 ORDER BY id ASC LIMIT ?"
        db.query(sql, arrayOf(limit.toString())).use { cursor ->
            while (cursor.moveToNext()) {
                list.add(
                    SyncChangeLog(
                        id = cursor.getLong(0),
                        entityType = cursor.getString(1),
                        entityId = cursor.getString(2),
                        operation = cursor.getString(3),
                        data = if (cursor.isNull(4)) null else cursor.getString(4),
                        timestamp = cursor.getLong(5),
                        lamportClock = cursor.getLong(6),
                        isSynced = cursor.getInt(7) == 1
                    )
                )
            }
        }
        return list
    }

    /**
     * Acknowledges that changes up to throughId have been committed by the sync server.
     */
    fun markChangesSynced(throughId: Long) {
        val cv = ContentValues().apply {
            put("isSynced", 1)
        }
        db.update("sync_change_log", android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE, cv, "id <= ?", arrayOf(throughId.toString()))
    }

    /**
     * Compactifies and garbage-collects synced log entries older than olderThanMs (default: 14 days).
     */
    fun pruneSyncedLogs(olderThanMs: Long = 14 * 24 * 60 * 60 * 1000L): Int {
        val cutoff = System.currentTimeMillis() - olderThanMs
        return db.delete("sync_change_log", "isSynced = 1 AND timestamp < ?", arrayOf(cutoff.toString()))
    }

    // --- Sync State (Key-Value Metadata) ---

    fun setSyncState(key: String, value: String) {
        val cv = ContentValues().apply {
            put("key", key)
            put("val", value)
        }
        db.insert("sync_state", android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE, cv)
    }

    fun getSyncState(key: String): String? {
        db.query("SELECT val FROM sync_state WHERE key = ?", arrayOf(key)).use { cursor ->
            if (cursor.moveToFirst()) {
                return cursor.getString(0)
            }
        }
        return null
    }
}
