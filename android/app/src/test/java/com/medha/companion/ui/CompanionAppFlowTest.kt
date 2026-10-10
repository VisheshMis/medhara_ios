package com.medha.companion.ui

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.medha.companion.data.local.MedhaDatabaseManager
import com.medha.companion.data.local.MedhaDatabaseOpenHelper
import com.medha.companion.data.model.Block
import com.medha.companion.data.model.BlockType
import com.medha.companion.data.model.Document
import com.medha.companion.data.model.FSRSRating
import com.medha.companion.data.model.Flashcard
import com.medha.companion.data.model.Notebook
import com.medha.companion.data.model.ReviewLog
import com.medha.companion.data.model.SyncOperation
import com.medha.companion.data.sync.LamportClock
import com.medha.companion.data.sync.MutationJournalManager
import com.medha.companion.domain.fsrs.FSRSScheduler
import org.json.JSONObject
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
class CompanionAppFlowTest {

    private lateinit var helper: MedhaDatabaseOpenHelper
    private lateinit var dbManager: MedhaDatabaseManager
    private lateinit var journalManager: MutationJournalManager
    private lateinit var clock: LamportClock

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        helper = MedhaDatabaseOpenHelper(context, "flow_test.db")
        dbManager = MedhaDatabaseManager(helper.writableDatabase)
        clock = LamportClock()
        journalManager = MutationJournalManager(helper.writableDatabase, clock)

        // Seed base notebook and documents to satisfy foreign key constraints
        dbManager.insertNotebook(Notebook(id = "nb-1", name = "Science", icon = "🔬"))
        dbManager.insertDocument(Document(id = "doc-study-guide", notebookId = "nb-1", title = "Guide"))
        dbManager.insertDocument(Document(id = "doc-chem", notebookId = "nb-1", title = "Chemistry"))
        dbManager.insertDocument(Document(id = "doc-neuro", notebookId = "nb-1", title = "Neuroscience"))
        dbManager.insertDocument(Document(id = "doc-inbox", notebookId = "nb-1", title = "Inbox"))
    }

    @After
    fun tearDown() {
        helper.close()
    }

    @Test
    fun testPhase6_DocumentHierarchyAndTodoToggle() {
        val docId = "doc-study-guide"
        dbManager.insertNotebook(Notebook(id = "nb-1", name = "Biology", icon = "🧬"))
        dbManager.insertDocument(Document(id = docId, notebookId = "nb-1", title = "Cell Division"))

        val bRoot = Block(id = "b-1", rootDocId = docId, type = BlockType.HEADING1, content = "Mitosis Stages", sortOrder = 0)
        val bTodo1 = Block(id = "b-2", rootDocId = docId, parentId = "b-1", type = BlockType.TASK_LIST, content = "Prophase review", sortOrder = 1, isCompleted = false)
        val bTodo2 = Block(id = "b-3", rootDocId = docId, parentId = "b-1", type = BlockType.TASK_LIST, content = "Metaphase review", sortOrder = 2, isCompleted = false)

        dbManager.insertBlock(bRoot)
        dbManager.insertBlock(bTodo1)
        dbManager.insertBlock(bTodo2)

        val blocks = dbManager.getBlocksByDocument(docId)
        assertEquals(3, blocks.size)

        // Toggle todo checkmark and log mutation
        val updated = bTodo1.copy(isCompleted = true)
        dbManager.insertBlock(updated)
        val changeId = journalManager.recordChange("block", updated.id, SyncOperation.UPDATE, "{\"isCompleted\":true}")
        assertTrue(changeId > 0)

        val reloaded = dbManager.getBlocksByDocument(docId)
        val toggled = reloaded.first { it.id == "b-2" }
        assertEquals(true, toggled.isCompleted)

        val unpushed = journalManager.getUnpushedChanges()
        assertEquals(1, unpushed.size)
        assertEquals("block", unpushed[0].entityType)
    }

    @Test
    fun testPhase6_FTS5SearchFlow() {
        val docId = "doc-chem"
        dbManager.insertBlock(Block(id = "b-c1", rootDocId = docId, content = "Photosynthesis generates glucose and oxygen.", sortOrder = 0))
        dbManager.insertBlock(Block(id = "b-c2", rootDocId = docId, content = "Cellular respiration produces ATP in mitochondria.", sortOrder = 1))

        val results = dbManager.searchFTS5("glucose")
        assertEquals(1, results.size)
        assertEquals("b-c1", results[0].blockId)
        assertTrue(results[0].snippet.contains("glucose"))
    }

    @Test
    fun testPhase7_FlashcardReviewCycleWithFSRSAndCDCJournal() {
        val card = Flashcard(
            id = "fc-neuro-1",
            docId = "doc-neuro",
            notebookId = "nb-1",
            front = "Action potential threshold?",
            back = "-55 mV",
            due = Instant.now().minusSeconds(3600).toString() // due now
        )
        dbManager.insertFlashcard(card)

        val dueCards = dbManager.getDueFlashcards(Instant.now().toString())
        assertEquals(1, dueCards.size)

        // Preview intervals before rating
        val scheduler = FSRSScheduler.shared
        val previews = scheduler.previewIntervals(dueCards[0])
        assertTrue(previews[FSRSRating.GOOD]!! >= 1)
        assertTrue(previews[FSRSRating.EASY]!! >= previews[FSRSRating.GOOD]!!)

        // User rates GOOD
        val reviewResult = scheduler.review(dueCards[0], FSRSRating.GOOD)
        dbManager.insertFlashcard(reviewResult.card)

        val log = ReviewLog(
            id = "rev-1",
            cardId = reviewResult.card.id,
            rating = FSRSRating.GOOD.value,
            state = "review",
            scheduledDays = reviewResult.intervalDays,
            elapsedDays = 0,
            reviewTime = Instant.now().toString()
        )
        dbManager.insertReviewLog(log)

        // Verify journal change entries recorded
        journalManager.recordChange("flashcard", reviewResult.card.id, SyncOperation.UPDATE, "{\"stability\":${reviewResult.newStability}}")
        journalManager.recordChange("review_log", log.id, SyncOperation.INSERT, "{\"rating\":3}")

        val unpushed = journalManager.getUnpushedChanges()
        assertEquals(2, unpushed.size)
        assertEquals("flashcard", unpushed[0].entityType)
        assertEquals("review_log", unpushed[1].entityType)

        // Card is now scheduled in future, so it shouldn't be due immediately
        val remainingDue = dbManager.getDueFlashcards(Instant.now().toString())
        assertTrue(remainingDue.isEmpty())
    }

    @Test
    fun testPhase8_QuickCaptureNoteAndCardModals() {
        // 1. Quick Note capture
        val noteBlock = Block(
            id = "b-quick-1",
            rootDocId = "doc-inbox",
            type = BlockType.PARAGRAPH,
            content = "Quick idea captured during morning commute."
        )
        dbManager.insertBlock(noteBlock)
        journalManager.recordChange("block", noteBlock.id, SyncOperation.INSERT, "{\"content\":\"Quick idea\"}")

        val blocks = dbManager.getBlocksByDocument("doc-inbox")
        assertEquals(1, blocks.size)
        assertEquals("Quick idea captured during morning commute.", blocks[0].content)

        // 2. Quick Flashcard capture
        val newCard = Flashcard(
            id = "fc-quick-1",
            docId = "doc-inbox",
            notebookId = "nb-1",
            front = "What is Amdahl's Law?",
            back = "Limits speedup from parallelization based on serial fraction."
        )
        dbManager.insertFlashcard(newCard)
        journalManager.recordChange("flashcard", newCard.id, SyncOperation.INSERT, "{\"front\":\"Amdahl\"}")

        val unpushed = journalManager.getUnpushedChanges()
        assertEquals(2, unpushed.size)
    }
}
