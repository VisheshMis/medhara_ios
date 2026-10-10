package com.medha.companion

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Style
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.medha.companion.data.local.FTS5SearchResult
import com.medha.companion.data.local.MedhaDatabaseManager
import com.medha.companion.data.local.MedhaDatabaseOpenHelper
import com.medha.companion.data.model.Block
import com.medha.companion.data.model.BlockType
import com.medha.companion.data.model.Document
import com.medha.companion.data.model.Flashcard
import com.medha.companion.data.model.Notebook
import com.medha.companion.data.model.ReviewLog
import com.medha.companion.data.model.SyncOperation
import com.medha.companion.data.sync.LamportClock
import com.medha.companion.data.sync.MedhaSyncWorker
import com.medha.companion.data.sync.MutationJournalManager
import com.medha.companion.ui.capture.CaptureFab
import com.medha.companion.ui.capture.QuickCardSheet
import com.medha.companion.ui.capture.QuickNoteSheet
import com.medha.companion.ui.reader.DocumentReaderScreen
import com.medha.companion.ui.search.SearchScreen
import com.medha.companion.ui.study.StudySessionScreen
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.time.Instant
import java.util.UUID

enum class Screen {
    READER,
    STUDY,
    SEARCH
}

class MainActivity : ComponentActivity() {

    private lateinit var dbHelper: MedhaDatabaseOpenHelper
    private lateinit var dbManager: MedhaDatabaseManager
    private lateinit var journalManager: MutationJournalManager
    private lateinit var clock: LamportClock

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        dbHelper = MedhaDatabaseOpenHelper(this)
        val db = dbHelper.writableDatabase
        dbManager = MedhaDatabaseManager(db)
        clock = LamportClock()
        journalManager = MutationJournalManager(db, clock)

        seedInitialDataIfEmpty()

        setContent {
            MaterialTheme {
                MainAppScreen(
                    dbManager = dbManager,
                    journalManager = journalManager,
                    onSyncRequested = {
                        MedhaSyncWorker.triggerImmediateSync(this@MainActivity)
                    }
                )
            }
        }
    }

    private fun seedInitialDataIfEmpty() {
        if (dbManager.getNotebooks().isEmpty()) {
            val nbId = "nb-default"
            dbManager.insertNotebook(
                Notebook(
                    id = nbId,
                    name = "Quick Thoughts & Study",
                    icon = "🧠",
                    sortOrder = 0,
                    isArchived = false
                )
            )

            val docId = "doc-welcome"
            dbManager.insertDocument(
                Document(
                    id = docId,
                    notebookId = nbId,
                    title = "Welcome to Medha Companion",
                    icon = "✨",
                    isFolder = false,
                    sortOrder = 0
                )
            )

            dbManager.insertBlock(
                Block(
                    id = "blk-1",
                    rootDocId = docId,
                    type = BlockType.HEADING1,
                    content = "Medha Mobile Companion",
                    sortOrder = 0
                )
            )

            dbManager.insertBlock(
                Block(
                    id = "blk-2",
                    rootDocId = docId,
                    type = BlockType.PARAGRAPH,
                    content = "Your pocket accessory for rapid reading, instant FTS5 search, and spaced repetition flashcard reviews.",
                    sortOrder = 1
                )
            )

            dbManager.insertBlock(
                Block(
                    id = "blk-3",
                    rootDocId = docId,
                    type = BlockType.TASK_LIST,
                    content = "Explore the Document Reader and toggle checkmarks",
                    isCompleted = false,
                    sortOrder = 2
                )
            )

            dbManager.insertBlock(
                Block(
                    id = "blk-4",
                    rootDocId = docId,
                    type = BlockType.TASK_LIST,
                    content = "Tap Study tab to review due flashcards with FSRS-4.5",
                    isCompleted = false,
                    sortOrder = 3
                )
            )

            // Seed initial sample flashcard
            dbManager.insertFlashcard(
                Flashcard(
                    id = "fc-sample-1",
                    docId = docId,
                    notebookId = nbId,
                    front = "What is the primary role of the Medha Android companion?",
                    back = "Consumption (reading notes), reviewing flashcards (FSRS-4.5), and rapid capture with offline sync.",
                    due = Instant.now().toString()
                )
            )
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        dbHelper.close()
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainAppScreen(
    dbManager: MedhaDatabaseManager,
    journalManager: MutationJournalManager,
    onSyncRequested: () -> Unit
) {
    var currentScreen by remember { mutableStateOf(Screen.READER) }
    var activeDocId by remember { mutableStateOf("doc-welcome") }
    var docTitle by remember { mutableStateOf("Welcome to Medha Companion") }

    // Blocks list state
    val blocks = remember { mutableStateListOf<Block>() }
    fun refreshBlocks() {
        blocks.clear()
        blocks.addAll(dbManager.getBlocksByDocument(activeDocId))
    }
    remember(activeDocId) { refreshBlocks() }

    // Flashcards state
    val dueCards = remember { mutableStateListOf<Flashcard>() }
    fun refreshDueCards() {
        dueCards.clear()
        dueCards.addAll(dbManager.getDueFlashcards(Instant.now().plusSeconds(86400).toString()))
    }
    remember(currentScreen) { refreshDueCards() }

    // FTS5 Search state
    var searchQuery by remember { mutableStateOf("") }
    val searchResults = remember { mutableStateListOf<FTS5SearchResult>() }

    // Sheets state
    var showQuickNoteSheet by remember { mutableStateOf(false) }
    var showQuickCardSheet by remember { mutableStateOf(false) }
    val noteSheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val cardSheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    val scope = rememberCoroutineScope()

    Scaffold(
        bottomBar = {
            if (currentScreen != Screen.SEARCH) {
                NavigationBar {
                    NavigationBarItem(
                        selected = currentScreen == Screen.READER,
                        onClick = { currentScreen = Screen.READER },
                        icon = { Icon(Icons.Default.MenuBook, contentDescription = "Notes") },
                        label = { Text("Notes") }
                    )
                    NavigationBarItem(
                        selected = currentScreen == Screen.STUDY,
                        onClick = {
                            refreshDueCards()
                            currentScreen = Screen.STUDY
                        },
                        icon = { Icon(Icons.Default.Style, contentDescription = "Study") },
                        label = {
                            val count = dueCards.size
                            Text(if (count > 0) "Study ($count)" else "Study")
                        }
                    )
                }
            }
        },
        floatingActionButton = {
            if (currentScreen != Screen.SEARCH) {
                CaptureFab(
                    onOpenQuickNote = { showQuickNoteSheet = true },
                    onOpenQuickCard = { showQuickCardSheet = true }
                )
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            when (currentScreen) {
                Screen.READER -> {
                    DocumentReaderScreen(
                        documentTitle = docTitle,
                        blocks = blocks,
                        onBackClick = { /* Top level document */ },
                        onSearchClick = { currentScreen = Screen.SEARCH },
                        onSyncClick = onSyncRequested,
                        onToggleTodo = { blockId, isCompleted ->
                            val blk = blocks.firstOrNull { it.id == blockId }
                            if (blk != null) {
                                val updated = blk.copy(isCompleted = isCompleted)
                                dbManager.insertBlock(updated)
                                val json = JSONObject().apply {
                                    put("id", updated.id)
                                    put("isCompleted", isCompleted)
                                }.toString()
                                journalManager.recordChange("block", updated.id, SyncOperation.UPDATE, json)
                                refreshBlocks()
                            }
                        }
                    )
                }
                Screen.STUDY -> {
                    StudySessionScreen(
                        deckName = "Active Recall Deck",
                        dueCards = dueCards,
                        onCardReviewed = { updatedCard, rating ->
                            dbManager.insertFlashcard(updatedCard)
                            val reviewLog = ReviewLog(
                                id = "rev-${UUID.randomUUID()}",
                                cardId = updatedCard.id,
                                rating = rating.value,
                                state = updatedCard.state.name.lowercase(),
                                scheduledDays = updatedCard.scheduledDays,
                                elapsedDays = updatedCard.elapsedDays,
                                reviewTime = Instant.now().toString()
                            )
                            dbManager.insertReviewLog(reviewLog)

                            // Record CDC journal entries for card update and review log
                            val cardJson = JSONObject().apply {
                                put("id", updatedCard.id)
                                put("fsrsState", updatedCard.fsrsState)
                                put("stability", updatedCard.stability)
                                put("difficulty", updatedCard.difficulty)
                                put("due", updatedCard.due)
                                put("reps", updatedCard.reps)
                                put("lapses", updatedCard.lapses)
                            }.toString()
                            journalManager.recordChange("flashcard", updatedCard.id, SyncOperation.UPDATE, cardJson)

                            val logJson = JSONObject().apply {
                                put("id", reviewLog.id)
                                put("cardId", reviewLog.cardId)
                                put("rating", reviewLog.rating)
                                put("scheduledDays", reviewLog.scheduledDays)
                                put("reviewTime", reviewLog.reviewTime)
                            }.toString()
                            journalManager.recordChange("review_log", reviewLog.id, SyncOperation.INSERT, logJson)

                            onSyncRequested()
                        },
                        onCloseSession = {
                            currentScreen = Screen.READER
                        }
                    )
                }
                Screen.SEARCH -> {
                    SearchScreen(
                        query = searchQuery,
                        onQueryChange = { q ->
                            searchQuery = q
                            searchResults.clear()
                            if (q.isNotBlank()) {
                                searchResults.addAll(dbManager.searchFTS5(q))
                            }
                        },
                        results = searchResults,
                        onResultClick = { rootDocId, _ ->
                            activeDocId = rootDocId
                            docTitle = "Document: $rootDocId"
                            refreshBlocks()
                            currentScreen = Screen.READER
                        },
                        onBackClick = {
                            currentScreen = Screen.READER
                        }
                    )
                }
            }
        }

        // Quick Note Modal Bottom Sheet
        if (showQuickNoteSheet) {
            QuickNoteSheet(
                sheetState = noteSheetState,
                onDismiss = { showQuickNoteSheet = false },
                onSaveNote = { title, content ->
                    val newBlock = Block(
                        id = "blk-${UUID.randomUUID()}",
                        rootDocId = activeDocId,
                        type = BlockType.PARAGRAPH,
                        content = content,
                        sortOrder = blocks.size
                    )
                    dbManager.insertBlock(newBlock)
                    val json = JSONObject().apply {
                        put("id", newBlock.id)
                        put("rootDocId", newBlock.rootDocId)
                        put("content", newBlock.content)
                        put("type", newBlock.type.typeName)
                    }.toString()
                    journalManager.recordChange("block", newBlock.id, SyncOperation.INSERT, json)
                    refreshBlocks()
                    onSyncRequested()
                }
            )
        }

        // Quick Flashcard Modal Bottom Sheet
        if (showQuickCardSheet) {
            QuickCardSheet(
                sheetState = cardSheetState,
                onDismiss = { showQuickCardSheet = false },
                onSaveCard = { front, back, hint, addAnother ->
                    val newCard = Flashcard(
                        id = "fc-${UUID.randomUUID()}",
                        docId = activeDocId,
                        notebookId = "nb-default",
                        front = front,
                        back = back,
                        hint = hint,
                        due = Instant.now().toString()
                    )
                    dbManager.insertFlashcard(newCard)
                    val cardJson = JSONObject().apply {
                        put("id", newCard.id)
                        put("docId", newCard.docId)
                        put("front", newCard.front)
                        put("back", newCard.back)
                        put("due", newCard.due)
                    }.toString()
                    journalManager.recordChange("flashcard", newCard.id, SyncOperation.INSERT, cardJson)
                    refreshDueCards()
                    onSyncRequested()
                }
            )
        }
    }
}
