package com.medha.companion.data.model

import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.temporal.ChronoUnit

class CoreModelsTest {

    private val json = Json {
        prettyPrint = true
        ignoreUnknownKeys = true
    }

    @Test
    fun testNotebookModelAndSerialization() {
        val notebook = Notebook(
            name = "Medical Pharmacology",
            icon = "pills.fill",
            sortOrder = 1
        )
        assertTrue(notebook.id.startsWith("nb-"))
        assertEquals("Medical Pharmacology", notebook.name)
        assertEquals("pills.fill", notebook.icon)
        assertEquals(1, notebook.sortOrder)

        val serialized = json.encodeToString(notebook)
        val deserialized = json.decodeFromString<Notebook>(serialized)
        assertEquals(notebook, deserialized)
    }

    @Test
    fun testDocumentModelAndSerialization() {
        val doc = Document(
            notebookId = "nb-123",
            parentId = null,
            title = "Cardiovascular Pharmacology",
            isFolder = false,
            sortOrder = 0
        )
        assertTrue(doc.id.startsWith("doc-"))
        assertEquals("nb-123", doc.notebookId)
        assertEquals("Cardiovascular Pharmacology", doc.title)
        assertFalse(doc.isFolder)

        val serialized = json.encodeToString(doc)
        val deserialized = json.decodeFromString<Document>(serialized)
        assertEquals(doc, deserialized)
    }

    @Test
    fun testBlockModelAll20ColumnsAnd14Types() {
        assertEquals(14, BlockType.entries.size)

        val expectedTypes = listOf(
            "doc", "inkDoc", "heading1", "heading2", "heading3",
            "paragraph", "bulletList", "taskList", "codeBlock",
            "quote", "callout", "blockRef", "toggle", "table"
        )
        for (typeName in expectedTypes) {
            val type = BlockType.fromString(typeName)
            assertEquals(typeName, type.typeName)
        }

        val future = Instant.now().plus(7, ChronoUnit.DAYS).toString()
        val block = Block(
            id = "b-custom-123",
            rootDocId = "doc-123",
            parentId = "b-parent-123",
            type = BlockType.CALLOUT,
            content = "Beta blockers decrease cardiac output.",
            sortOrder = 2,
            isCompleted = false,
            refTargetId = "b-ref-target",
            createdAt = "2026-10-09T14:00:00Z",
            updatedAt = "2026-10-09T14:05:00Z",
            notebookId = "nb-123",
            canvasMode = "a4Pages",
            isCollapsed = false,
            icon = "lightbulb.fill",
            colorTint = "#3B82F6",
            verifiedAt = "2026-10-09T14:00:00Z",
            verifiedExpiresAt = future,
            verifiedBy = "Dr. Medha",
            isLocked = false,
            pinnedPropertiesData = "{\"badge\":\"High Yield\"}"
        )

        assertEquals("b-custom-123", block.id)
        assertEquals("doc-123", block.rootDocId)
        assertEquals("b-parent-123", block.parentId)
        assertEquals(BlockType.CALLOUT, block.type)
        assertEquals("Beta blockers decrease cardiac output.", block.content)
        assertEquals(2, block.sortOrder)
        assertEquals(false, block.isCompleted)
        assertEquals("b-ref-target", block.refTargetId)
        assertEquals("nb-123", block.notebookId)
        assertEquals("a4Pages", block.canvasMode)
        assertEquals(false, block.isCollapsed)
        assertEquals("lightbulb.fill", block.icon)
        assertEquals("#3B82F6", block.colorTint)
        assertEquals("Dr. Medha", block.verifiedBy)
        assertTrue(block.isVerified)
        assertFalse(block.isDocument)
        assertFalse(block.isHeading)

        val headingBlock = Block(rootDocId = "doc-123", type = BlockType.HEADING1, content = "Overview")
        assertTrue(headingBlock.isHeading)

        val docBlock = Block(rootDocId = "doc-123", type = BlockType.DOC, content = "Note Title")
        assertTrue(docBlock.isDocument)

        val serialized = json.encodeToString(block)
        val deserialized = json.decodeFromString<Block>(serialized)
        assertEquals(block, deserialized)
    }

    @Test
    fun testFlashcardModelAll25ColumnsAndEnums() {
        assertEquals(4, FSRSState.entries.size)
        assertEquals(4, FSRSRating.entries.size)
        assertEquals(2, FlashcardType.entries.size)
        assertEquals(2, OcclusionMode.entries.size)

        val card = Flashcard(
            id = "fc-card-001",
            docId = "doc-123",
            notebookId = "nb-123",
            front = "What is the primary mechanism of action of Metoprolol?",
            back = "Selective beta-1 adrenergic receptor antagonist.",
            sourceBlockId = "b-123",
            hint = "Focus on receptor subtype",
            fsrsState = FSRSState.REVIEW.value,
            stability = 24.5,
            difficulty = 3.2,
            elapsedDays = 5,
            scheduledDays = 25,
            reps = 4,
            lapses = 0,
            lastReview = "2026-10-04T12:00:00Z",
            due = "2026-10-29T12:00:00Z",
            deckId = "deck-notes-default",
            isSuspended = false,
            cardType = FlashcardType.STANDARD.value,
            imagePath = null,
            occlusionMasksData = null,
            activeMaskId = null,
            occlusionMode = OcclusionMode.HIDE_ALL_REVEAL_ONE.value,
            createdAt = "2026-10-01T10:00:00Z",
            updatedAt = "2026-10-04T12:00:00Z"
        )

        assertEquals(FSRSState.REVIEW, card.state)
        assertEquals(FlashcardType.STANDARD, card.type)
        assertEquals(OcclusionMode.HIDE_ALL_REVEAL_ONE, card.mode)
        assertFalse(card.isEffectivelySuspended)

        val serialized = json.encodeToString(card)
        val deserialized = json.decodeFromString<Flashcard>(serialized)
        assertEquals(card, deserialized)
    }

    @Test
    fun testReviewLogModel() {
        val log = ReviewLog(
            cardId = "fc-card-001",
            rating = FSRSRating.GOOD.value,
            state = "review",
            elapsedDays = 5,
            scheduledDays = 25
        )
        assertTrue(log.id.startsWith("rev-"))
        assertEquals("fc-card-001", log.cardId)
        assertEquals(3, log.rating)
        assertEquals("review", log.state)
        assertEquals(5, log.elapsedDays)
        assertEquals(25, log.scheduledDays)
        assertNotNull(log.reviewTime)

        val serialized = json.encodeToString(log)
        val deserialized = json.decodeFromString<ReviewLog>(serialized)
        assertEquals(log, deserialized)
    }

    @Test
    fun testDeckAndDeckOptionsModels() {
        val deck = Deck(
            name = "Cardiology",
            description = "High-yield cardiology flashcards",
            colorHex = "#EF4444",
            icon = "heart.fill",
            isNotesDefault = false,
            presetId = "preset-cardio"
        )
        assertTrue(deck.id.startsWith("deck-"))
        assertEquals("Cardiology", deck.name)
        assertEquals("deck-notes-default", Deck.NOTES_DEFAULT_ID)

        val deckSerialized = json.encodeToString(deck)
        val deckDeserialized = json.decodeFromString<Deck>(deckSerialized)
        assertEquals(deck, deckDeserialized)

        val options = DeckOptions(
            name = "Aggressive Review",
            isDefault = true,
            maxNewCardsPerDay = 30,
            maxReviewsPerDay = 300,
            learningSteps = "1m 5m 15m",
            insertionOrder = DeckInsertionOrder.RANDOM.rawValue,
            relearningSteps = "15m",
            leechThreshold = 6,
            leechAction = DeckLeechAction.SUSPEND.rawValue,
            newCardGatherOrder = NewCardGatherOrder.RANDOM.rawValue,
            newCardSortOrder = NewCardSortOrder.CARD_TYPE.rawValue,
            newReviewOrder = NewReviewOrder.BEFORE_REVIEWS.rawValue,
            interdayOrder = InterdayOrder.AFTER_REVIEWS.rawValue,
            reviewSortOrder = ReviewSortOrder.RANDOM.rawValue,
            desiredRetention = 0.88,
            maximumInterval = 18250,
            historicalRetention = 0.88
        )

        assertEquals(DeckInsertionOrder.RANDOM, options.parsedInsertionOrder)
        assertEquals(DeckLeechAction.SUSPEND, options.parsedLeechAction)
        assertEquals(NewCardGatherOrder.RANDOM, options.parsedNewCardGatherOrder)
        assertEquals(NewCardSortOrder.CARD_TYPE, options.parsedNewCardSortOrder)
        assertEquals(NewReviewOrder.BEFORE_REVIEWS, options.parsedNewReviewOrder)
        assertEquals(InterdayOrder.AFTER_REVIEWS, options.parsedInterdayOrder)
        assertEquals(ReviewSortOrder.RANDOM, options.parsedReviewSortOrder)

        val optionsSerialized = json.encodeToString(options)
        val optionsDeserialized = json.decodeFromString<DeckOptions>(optionsSerialized)
        assertEquals(options, optionsDeserialized)
    }

    @Test
    fun testSyncChangeLogModel() {
        val syncLog = SyncChangeLog(
            id = 101L,
            entityType = "block",
            entityId = "b-123",
            operation = "UPDATE",
            data = "{\"content\":\"Updated block content\"}",
            timestamp = 1728480000000L,
            lamportClock = 42L,
            isSynced = false
        )

        assertEquals(101L, syncLog.id)
        assertEquals("block", syncLog.entityType)
        assertEquals("b-123", syncLog.entityId)
        assertEquals(SyncOperation.UPDATE, syncLog.syncOperation)
        assertEquals(42L, syncLog.lamportClock)
        assertFalse(syncLog.isSynced)

        val serialized = json.encodeToString(syncLog)
        val deserialized = json.decodeFromString<SyncChangeLog>(serialized)
        assertEquals(syncLog, deserialized)
    }
}
