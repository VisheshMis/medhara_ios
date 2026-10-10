package com.medha.companion.data.sync

import android.content.ContentValues
import androidx.sqlite.db.SupportSQLiteDatabase
import com.medha.companion.data.model.BlockType
import org.json.JSONObject

data class SyncCycleResult(
    val success: Boolean,
    val pushedCount: Int = 0,
    val pulledCount: Int = 0,
    val error: String? = null
)

/**
 * Orchestrates two-way delta sync cycle between local SQLite database and remote Medha Sync Server.
 */
class MedhaSyncManager(
    private val db: SupportSQLiteDatabase,
    private val journalManager: MutationJournalManager,
    private val syncClient: MedhaSyncClient,
    private val lamportClock: LamportClock,
    val deviceId: String = "android_" + java.util.UUID.randomUUID().toString().substring(0, 8)
) {

    fun performFullSync(): SyncCycleResult {
        var totalPushed = 0
        var totalPulled = 0

        try {
            // 1. Push local unpushed changes
            val unpushed = journalManager.getUnpushedChanges(limit = 250)
            if (unpushed.isNotEmpty()) {
                val pushResult = syncClient.push(deviceId, unpushed)
                if (!pushResult.success) {
                    return SyncCycleResult(success = false, error = pushResult.error)
                }
                journalManager.markChangesSynced(pushResult.acceptedThroughChangeId)
                lamportClock.update(pushResult.serverLamport)
                totalPushed = unpushed.size
            }

            // 2. Pull remote changes incrementally
            val lastCursorStr = journalManager.getSyncState("last_server_cursor")
            var currentCursor = lastCursorStr?.toLongOrNull() ?: 0L
            var hasMore = true

            while (hasMore) {
                val pullResult = syncClient.pull(sinceCursor = currentCursor, limit = 250)
                if (pullResult.error != null) {
                    return SyncCycleResult(success = false, pushedCount = totalPushed, error = pullResult.error)
                }

                if (pullResult.changes.isNotEmpty()) {
                    applyRemoteChanges(pullResult.changes)
                    totalPulled += pullResult.changes.size
                    currentCursor = pullResult.serverCursor
                    journalManager.setSyncState("last_server_cursor", currentCursor.toString())
                    lamportClock.update(pullResult.serverLamport)
                } else {
                    currentCursor = pullResult.serverCursor
                    journalManager.setSyncState("last_server_cursor", currentCursor.toString())
                }

                hasMore = pullResult.hasMore
            }

            // 3. Prune old synced logs
            journalManager.pruneSyncedLogs()

            return SyncCycleResult(
                success = true,
                pushedCount = totalPushed,
                pulledCount = totalPulled
            )
        } catch (e: Exception) {
            return SyncCycleResult(
                success = false,
                pushedCount = totalPushed,
                pulledCount = totalPulled,
                error = e.message ?: "Sync failed"
            )
        }
    }

    /**
     * Applies a batch of remote changes inside a single atomic SQLite transaction.
     */
    fun applyRemoteChanges(changes: List<RemoteChange>) {
        db.beginTransaction()
        try {
            for (ch in changes) {
                // If the change originated from this device, skip local re-application
                if (ch.deviceId == deviceId) {
                    continue
                }

                when (ch.operation.uppercase()) {
                    "DELETE" -> {
                        when (ch.entityType) {
                            "notebook" -> db.delete("notebook", "id = ?", arrayOf(ch.entityId))
                            "document" -> db.delete("document", "id = ?", arrayOf(ch.entityId))
                            "block" -> db.delete("block", "id = ?", arrayOf(ch.entityId))
                            "flashcard" -> db.delete("flashcard", "id = ?", arrayOf(ch.entityId))
                            "deck" -> db.delete("deck", "id = ?", arrayOf(ch.entityId))
                        }
                    }
                    "INSERT", "UPDATE" -> {
                        if (ch.data.isNullOrBlank()) continue
                        val json = try {
                            JSONObject(ch.data)
                        } catch (e: Exception) {
                            continue
                        }

                        when (ch.entityType) {
                            "notebook" -> applyNotebook(ch.entityId, json)
                            "document" -> applyDocument(ch.entityId, json)
                            "block" -> applyBlock(ch.entityId, json)
                            "flashcard" -> applyFlashcard(ch.entityId, json)
                            "review_log" -> applyReviewLog(ch.entityId, json)
                            "deck" -> applyDeck(ch.entityId, json)
                        }
                    }
                }
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    private fun applyNotebook(id: String, json: JSONObject) {
        val cv = ContentValues().apply {
            put("id", id)
            put("name", json.optString("name", "Untitled"))
            put("icon", json.optString("icon", "📁"))
            put("sortOrder", json.optInt("sortOrder", 0))
            put("isArchived", if (json.optBoolean("isArchived", false)) 1 else 0)
            put("updatedAt", json.optString("updatedAt", java.time.Instant.now().toString()))
        }
        db.insert("notebook", android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE, cv)
    }

    private fun applyDocument(id: String, json: JSONObject) {
        val cv = ContentValues().apply {
            put("id", id)
            put("notebookId", json.optString("notebookId", "default"))
            put("parentId", if (json.isNull("parentId")) null else json.optString("parentId"))
            put("title", json.optString("title", "Untitled"))
            put("icon", json.optString("icon", "📄"))
            put("isFolder", if (json.optBoolean("isFolder", false)) 1 else 0)
            put("sortOrder", json.optInt("sortOrder", 0))
            put("isPinned", if (json.optBoolean("isPinned", false)) 1 else 0)
            put("createdAt", json.optString("createdAt", java.time.Instant.now().toString()))
            put("updatedAt", json.optString("updatedAt", java.time.Instant.now().toString()))
        }
        db.insert("document", android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE, cv)
    }

    private fun applyBlock(id: String, json: JSONObject) {
        val typeStr = json.optString("type", "paragraph")
        val blockType = BlockType.fromString(typeStr)
        val cv = ContentValues().apply {
            put("id", id)
            put("rootDocId", json.optString("rootDocId", json.optString("documentId", "")))
            put("parentId", if (json.isNull("parentId")) null else json.optString("parentId"))
            put("type", blockType.typeName)
            put("content", json.optString("content", ""))
            put("sortOrder", json.optInt("sortOrder", 0))
            put("isCompleted", if (json.optBoolean("isCompleted", false)) 1 else 0)
            put("refTargetId", if (json.isNull("refTargetId")) null else json.optString("refTargetId"))
            put("createdAt", json.optString("createdAt", java.time.Instant.now().toString()))
            put("updatedAt", json.optString("updatedAt", java.time.Instant.now().toString()))
            put("notebookId", if (json.isNull("notebookId")) null else json.optString("notebookId"))
        }
        db.insert("block", android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE, cv)
    }

    private fun applyFlashcard(id: String, json: JSONObject) {
        val cv = ContentValues().apply {
            put("id", id)
            put("docId", json.optString("docId", ""))
            put("notebookId", json.optString("notebookId", "default"))
            put("front", json.optString("front", ""))
            put("back", json.optString("back", ""))
            put("sourceBlockId", if (json.isNull("sourceBlockId")) null else json.optString("sourceBlockId"))
            put("hint", if (json.isNull("hint")) null else json.optString("hint"))
            put("fsrsState", json.optInt("fsrsState", 0))
            put("stability", json.optDouble("stability", 0.0))
            put("difficulty", json.optDouble("difficulty", 0.0))
            put("elapsedDays", json.optInt("elapsedDays", 0))
            put("scheduledDays", json.optInt("scheduledDays", 0))
            put("reps", json.optInt("reps", 0))
            put("lapses", json.optInt("lapses", 0))
            put("lastReview", if (json.isNull("lastReview")) null else json.optString("lastReview"))
            put("due", json.optString("due", java.time.Instant.now().toString()))
            put("createdAt", json.optString("createdAt", java.time.Instant.now().toString()))
            put("updatedAt", json.optString("updatedAt", java.time.Instant.now().toString()))
        }
        db.insert("flashcard", android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE, cv)
    }

    private fun applyReviewLog(id: String, json: JSONObject) {
        val cv = ContentValues().apply {
            put("id", id)
            put("cardId", json.optString("cardId", ""))
            put("rating", json.optInt("rating", 3))
            put("state", json.optString("state", "review"))
            put("scheduledDays", json.optInt("scheduledDays", 1))
            put("elapsedDays", json.optInt("elapsedDays", 0))
            put("reviewTime", json.optString("reviewTime", java.time.Instant.now().toString()))
        }
        db.insert("review_log", android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE, cv)
    }

    private fun applyDeck(id: String, json: JSONObject) {
        val cv = ContentValues().apply {
            put("id", id)
            put("name", json.optString("name", "Default Deck"))
            put("description", if (json.isNull("description")) null else json.optString("description"))
            put("createdAt", json.optString("createdAt", java.time.Instant.now().toString()))
            put("updatedAt", json.optString("updatedAt", java.time.Instant.now().toString()))
        }
        db.insert("deck", android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE, cv)
    }
}
