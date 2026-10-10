package com.medha.companion.data.local

import android.content.ContentValues
import androidx.sqlite.db.SupportSQLiteDatabase
import com.medha.companion.data.model.Block
import com.medha.companion.data.model.BlockType
import com.medha.companion.data.model.Document
import com.medha.companion.data.model.Flashcard
import com.medha.companion.data.model.Notebook
import com.medha.companion.data.model.ReviewLog

data class FTS5SearchResult(
    val blockId: String,
    val rootDocId: String,
    val snippet: String,
    val rank: Double
)

/**
 * High-performance database operations manager for notes, flashcards, and FTS5 search.
 */
class MedhaDatabaseManager(private val db: SupportSQLiteDatabase) {

    // --- NOTEBOOKS ---

    fun insertNotebook(notebook: Notebook) {
        val cv = ContentValues().apply {
            put("id", notebook.id)
            put("name", notebook.name)
            put("icon", notebook.icon)
            put("sortOrder", notebook.sortOrder)
            put("isArchived", if (notebook.isArchived) 1 else 0)
            put("updatedAt", notebook.updatedAt)
        }
        db.insert("notebook", android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE, cv)
    }

    fun getNotebooks(): List<Notebook> {
        val list = mutableListOf<Notebook>()
        db.query("SELECT id, name, icon, sortOrder, isArchived, updatedAt FROM notebook WHERE isArchived = 0 ORDER BY sortOrder ASC").use { cursor ->
            while (cursor.moveToNext()) {
                list.add(
                    Notebook(
                        id = cursor.getString(0),
                        name = cursor.getString(1),
                        icon = cursor.getString(2),
                        sortOrder = cursor.getInt(3),
                        isArchived = cursor.getInt(4) == 1,
                        updatedAt = cursor.getString(5)
                    )
                )
            }
        }
        return list
    }

    fun deleteNotebook(id: String) {
        db.delete("notebook", "id = ?", arrayOf(id))
    }

    // --- DOCUMENTS ---

    fun insertDocument(doc: Document) {
        val cv = ContentValues().apply {
            put("id", doc.id)
            put("notebookId", doc.notebookId)
            put("parentId", doc.parentId)
            put("title", doc.title)
            put("icon", doc.icon)
            put("isFolder", if (doc.isFolder) 1 else 0)
            put("sortOrder", doc.sortOrder)
            put("isPinned", if (doc.isPinned) 1 else 0)
            put("createdAt", doc.createdAt)
            put("updatedAt", doc.updatedAt)
        }
        db.insert("document", android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE, cv)
    }

    fun getDocumentsByNotebook(notebookId: String): List<Document> {
        val list = mutableListOf<Document>()
        db.query("SELECT id, notebookId, parentId, title, icon, isFolder, sortOrder, isPinned, createdAt, updatedAt FROM document WHERE notebookId = ? ORDER BY sortOrder ASC", arrayOf(notebookId)).use { cursor ->
            while (cursor.moveToNext()) {
                list.add(
                    Document(
                        id = cursor.getString(0),
                        notebookId = cursor.getString(1),
                        parentId = cursor.getString(2),
                        title = cursor.getString(3),
                        icon = cursor.getString(4),
                        isFolder = cursor.getInt(5) == 1,
                        sortOrder = cursor.getInt(6),
                        isPinned = cursor.getInt(7) == 1,
                        createdAt = cursor.getString(8),
                        updatedAt = cursor.getString(9)
                    )
                )
            }
        }
        return list
    }

    // --- BLOCKS ---

    fun insertBlock(block: Block) {
        val cv = ContentValues().apply {
            put("id", block.id)
            put("rootDocId", block.rootDocId)
            put("parentId", block.parentId)
            put("type", block.type.typeName)
            put("content", block.content)
            put("sortOrder", block.sortOrder)
            put("isCompleted", if (block.isCompleted == true) 1 else 0)
            put("refTargetId", block.refTargetId)
            put("createdAt", block.createdAt)
            put("updatedAt", block.updatedAt)
            put("notebookId", block.notebookId)
        }
        db.insert("block", android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE, cv)
    }

    fun updateBlockContent(id: String, content: String, updatedAt: String = java.time.Instant.now().toString()) {
        val cv = ContentValues().apply {
            put("content", content)
            put("updatedAt", updatedAt)
        }
        db.update("block", android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE, cv, "id = ?", arrayOf(id))
    }

    fun getBlocksByDocument(docId: String): List<Block> {
        val list = mutableListOf<Block>()
        db.query("SELECT id, rootDocId, parentId, type, content, sortOrder, isCompleted, refTargetId, createdAt, updatedAt, notebookId FROM block WHERE rootDocId = ? ORDER BY sortOrder ASC", arrayOf(docId)).use { cursor ->
            while (cursor.moveToNext()) {
                list.add(
                    Block(
                        id = cursor.getString(0),
                        rootDocId = cursor.getString(1),
                        parentId = cursor.getString(2),
                        type = BlockType.fromString(cursor.getString(3)),
                        content = cursor.getString(4),
                        sortOrder = cursor.getInt(5),
                        isCompleted = cursor.getInt(6) == 1,
                        refTargetId = cursor.getString(7),
                        createdAt = cursor.getString(8),
                        updatedAt = cursor.getString(9),
                        notebookId = cursor.getString(10)
                    )
                )
            }
        }
        return list
    }

    fun deleteBlock(id: String) {
        db.delete("block", "id = ?", arrayOf(id))
    }

    // --- FTS5 SEARCH ---

    fun searchFTS5(queryText: String, limit: Int = 50): List<FTS5SearchResult> {
        val safeQuery = queryText.trim()
        if (safeQuery.isBlank()) return emptyList()

        val ftsQuery = if (safeQuery.endsWith("*")) safeQuery else "$safeQuery*"

        val sql = """
            SELECT id, rootDocId, snippet(block_fts, 2, '<b>', '</b>', '...', 15) AS snippet, bm25(block_fts) AS rank
            FROM block_fts
            WHERE block_fts MATCH ?
            ORDER BY rank ASC
            LIMIT ?
        """.trimIndent()

        val list = mutableListOf<FTS5SearchResult>()
        try {
            db.query(sql, arrayOf(ftsQuery, limit.toString())).use { cursor ->
                while (cursor.moveToNext()) {
                    list.add(
                        FTS5SearchResult(
                            blockId = cursor.getString(0),
                            rootDocId = cursor.getString(1),
                            snippet = cursor.getString(2),
                            rank = cursor.getDouble(3)
                        )
                    )
                }
            }
        } catch (e: android.database.sqlite.SQLiteException) {
            // Fallback for runtimes without FTS5: perform SQL LIKE query
            val likeSql = "SELECT id, rootDocId, content FROM block WHERE content LIKE ? LIMIT ?"
            db.query(likeSql, arrayOf("%$safeQuery%", limit.toString())).use { cursor ->
                while (cursor.moveToNext()) {
                    list.add(
                        FTS5SearchResult(
                            blockId = cursor.getString(0),
                            rootDocId = cursor.getString(1),
                            snippet = "<b>$safeQuery</b> in " + cursor.getString(2),
                            rank = 0.0
                        )
                    )
                }
            }
        }
        return list
    }

    // --- FLASHCARDS & REVIEWS ---

    fun insertFlashcard(card: Flashcard) {
        val cv = ContentValues().apply {
            put("id", card.id)
            put("docId", card.docId)
            put("notebookId", card.notebookId)
            put("front", card.front)
            put("back", card.back)
            put("sourceBlockId", card.sourceBlockId)
            put("hint", card.hint)
            put("fsrsState", card.fsrsState)
            put("stability", card.stability)
            put("difficulty", card.difficulty)
            put("elapsedDays", card.elapsedDays)
            put("scheduledDays", card.scheduledDays)
            put("reps", card.reps)
            put("lapses", card.lapses)
            put("lastReview", card.lastReview)
            put("due", card.due)
            put("createdAt", card.createdAt)
            put("updatedAt", card.updatedAt)
        }
        db.insert("flashcard", android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE, cv)
    }

    fun getDueFlashcards(nowIso: String = java.time.Instant.now().toString(), limit: Int = 100): List<Flashcard> {
        val list = mutableListOf<Flashcard>()
        val sql = "SELECT id, docId, notebookId, front, back, sourceBlockId, hint, fsrsState, stability, difficulty, elapsedDays, scheduledDays, reps, lapses, lastReview, due, createdAt, updatedAt FROM flashcard WHERE due <= ? ORDER BY due ASC LIMIT ?"
        db.query(sql, arrayOf(nowIso, limit.toString())).use { cursor ->
            while (cursor.moveToNext()) {
                list.add(
                    Flashcard(
                        id = cursor.getString(0),
                        docId = cursor.getString(1),
                        notebookId = cursor.getString(2),
                        front = cursor.getString(3),
                        back = cursor.getString(4),
                        sourceBlockId = cursor.getString(5),
                        hint = cursor.getString(6),
                        fsrsState = cursor.getInt(7),
                        stability = cursor.getDouble(8),
                        difficulty = cursor.getDouble(9),
                        elapsedDays = cursor.getInt(10),
                        scheduledDays = cursor.getInt(11),
                        reps = cursor.getInt(12),
                        lapses = cursor.getInt(13),
                        lastReview = if (cursor.isNull(14)) null else cursor.getString(14),
                        due = cursor.getString(15),
                        createdAt = cursor.getString(16),
                        updatedAt = cursor.getString(17)
                    )
                )
            }
        }
        return list
    }

    fun insertReviewLog(log: ReviewLog) {
        val cv = ContentValues().apply {
            put("id", log.id)
            put("cardId", log.cardId)
            put("rating", log.rating)
            put("state", log.state)
            put("scheduledDays", log.scheduledDays)
            put("elapsedDays", log.elapsedDays)
            put("reviewTime", log.reviewTime)
        }
        db.insert("review_log", android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE, cv)
    }
}
