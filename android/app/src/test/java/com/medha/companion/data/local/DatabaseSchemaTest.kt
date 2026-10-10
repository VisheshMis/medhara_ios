package com.medha.companion.data.local

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.medha.companion.data.model.Block
import com.medha.companion.data.model.BlockType
import com.medha.companion.data.model.Document
import com.medha.companion.data.model.Flashcard
import com.medha.companion.data.model.Notebook
import com.medha.companion.data.model.ReviewLog
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.Instant

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class DatabaseSchemaTest {

    private lateinit var helper: MedhaDatabaseOpenHelper
    private lateinit var manager: MedhaDatabaseManager

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        helper = MedhaDatabaseOpenHelper(context, "test_db.db")
        manager = MedhaDatabaseManager(helper.writableDatabase)
    }

    @After
    fun tearDown() {
        helper.close()
    }

    @Test
    fun testNotebookAndDocumentCascadeDelete() {
        val now = Instant.now().toString()
        val notebook = Notebook(
            id = "nb-1",
            name = "Medical Neuroscience",
            icon = "brain",
            sortOrder = 0,
            isArchived = false,
            updatedAt = now
        )
        manager.insertNotebook(notebook)

        val doc = Document(
            id = "doc-1",
            notebookId = "nb-1",
            title = "Cranial Nerves",
            icon = "doc",
            sortOrder = 0,
            isPinned = false,
            createdAt = now,
            updatedAt = now
        )
        manager.insertDocument(doc)

        val block = Block(
            id = "b-1",
            rootDocId = "doc-1",
            parentId = null,
            type = BlockType.PARAGRAPH,
            content = "CN X Vagus nerve supplies the parasympathetic viscera.",
            sortOrder = 0,
            isCompleted = false,
            refTargetId = null,
            createdAt = now,
            updatedAt = now,
            notebookId = "nb-1"
        )
        manager.insertBlock(block)

        // Verify insertion
        assertEquals(1, manager.getNotebooks().size)
        assertEquals(1, manager.getDocumentsByNotebook("nb-1").size)
        assertEquals(1, manager.getBlocksByDocument("doc-1").size)

        // Delete parent notebook
        manager.deleteNotebook("nb-1")

        // Assert cascading delete
        assertEquals(0, manager.getNotebooks().size)
        assertEquals(0, manager.getDocumentsByNotebook("nb-1").size)
        assertEquals(0, manager.getBlocksByDocument("doc-1").size)
    }

    @Test
    fun testFTS5TriggersSyncAndSearch() {
        val now = "2026-10-10T00:00:00Z"
        val notebook = Notebook(id = "nb-1", name = "Pathology", icon = null, sortOrder = 0, isArchived = false, updatedAt = now)
        manager.insertNotebook(notebook)

        val doc = Document(id = "doc-1", notebookId = "nb-1", title = "Inflammation", icon = null, sortOrder = 0, isPinned = false, createdAt = now, updatedAt = now)
        manager.insertDocument(doc)

        val b1 = Block(id = "b-1", rootDocId = "doc-1", parentId = null, type = BlockType.HEADING1, content = "Acute Inflammation Pathways", sortOrder = 0, isCompleted = false, refTargetId = null, createdAt = now, updatedAt = now, notebookId = "nb-1")
        val b2 = Block(id = "b-2", rootDocId = "doc-1", parentId = "b-1", type = BlockType.PARAGRAPH, content = "Histamine causes arteriolar vasodilation.", sortOrder = 1, isCompleted = false, refTargetId = null, createdAt = now, updatedAt = now, notebookId = "nb-1")
        manager.insertBlock(b1)
        manager.insertBlock(b2)

        // 1. Search for 'Histamine'
        val results1 = manager.searchFTS5("Histamine")
        assertEquals(1, results1.size)
        assertEquals("b-2", results1[0].blockId)
        assertTrue(results1[0].snippet.contains("Histamine"))

        // 2. Update block b-2 and verify FTS5 updates
        manager.updateBlockContent("b-2", "Serotonin and bradykinin increase vascular permeability.")

        val results2 = manager.searchFTS5("Histamine")
        assertEquals(0, results2.size)

        val results3 = manager.searchFTS5("bradykinin")
        assertEquals(1, results3.size)
        assertEquals("b-2", results3[0].blockId)

        // 3. Delete block b-2 and verify FTS5 deletes
        manager.deleteBlock("b-2")
        val results4 = manager.searchFTS5("bradykinin")
        assertEquals(0, results4.size)
    }

    @Test
    fun testFlashcardAndReviewLogCascade() {
        val now = Instant.now().toString()
        val card = Flashcard(
            id = "c-1",
            docId = "doc-1",
            notebookId = "nb-1",
            front = "What is the rate-limiting enzyme of glycolysis?",
            back = "Phosphofructokinase-1 (PFK-1)",
            sourceBlockId = null,
            hint = null,
            fsrsState = 0,
            stability = 0.0,
            difficulty = 0.0,
            elapsedDays = 0,
            scheduledDays = 0,
            reps = 0,
            lapses = 0,
            lastReview = null,
            due = now,
            createdAt = now,
            updatedAt = now
        )
        manager.insertFlashcard(card)

        val dueCards = manager.getDueFlashcards(nowIso = Instant.now().plusSeconds(60).toString())
        assertEquals(1, dueCards.size)
        assertEquals("c-1", dueCards[0].id)

        val log = ReviewLog(
            id = "log-1",
            cardId = "c-1",
            rating = 3, // Good
            state = "learning",
            scheduledDays = 1,
            elapsedDays = 0,
            reviewTime = now
        )
        manager.insertReviewLog(log)

        // Delete card and verify log cascades
        helper.writableDatabase.delete("flashcard", "id = ?", arrayOf("c-1"))
        helper.writableDatabase.query("SELECT COUNT(*) FROM review_log WHERE cardId = 'c-1'").use { cursor ->
            cursor.moveToFirst()
            assertEquals(0, cursor.getInt(0))
        }
    }
}
