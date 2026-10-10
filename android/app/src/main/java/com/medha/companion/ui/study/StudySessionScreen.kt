package com.medha.companion.ui.study

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.medha.companion.data.model.Flashcard
import com.medha.companion.data.model.FSRSRating
import com.medha.companion.domain.fsrs.FSRSScheduler

/**
 * Material 3 Flashcard Study Session Screen with active card queue, 3D flip card, and FSRS review pipeline.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StudySessionScreen(
    deckName: String = "Neuroscience",
    dueCards: List<Flashcard>,
    onCardReviewed: (Flashcard, FSRSRating) -> Unit,
    onCloseSession: () -> Unit
) {
    var currentIndex by remember { mutableIntStateOf(0) }
    var isFlipped by remember { mutableStateOf(false) }

    val scheduler = remember { FSRSScheduler.shared }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = deckName,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold
                        )
                        if (dueCards.isNotEmpty() && currentIndex < dueCards.size) {
                            Text(
                                text = "Card ${currentIndex + 1} of ${dueCards.size}",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onCloseSession) {
                        Icon(Icons.Default.Close, contentDescription = "Close Study Session")
                    }
                }
            )
        }
    ) { innerPadding ->
        if (dueCards.isEmpty() || currentIndex >= dueCards.size) {
            // All caught up state
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.padding(24.dp)
                ) {
                    Text(
                        text = "🎉",
                        style = MaterialTheme.typography.displayLarge
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        text = "All Caught Up!",
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "You've completed all due flashcards in this deck.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(24.dp))
                    Button(onClick = onCloseSession) {
                        Text("Return to Notes")
                    }
                }
            }
        } else {
            val currentCard = dueCards[currentIndex]

            // Calculate live preview intervals for all 4 ratings
            val previewIntervals = remember(currentCard.id) {
                val rawMap = scheduler.previewIntervals(currentCard)
                rawMap.mapValues { (_, days) -> scheduler.formatInterval(days) }
            }

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
                    .padding(horizontal = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Spacer(modifier = Modifier.height(16.dp))

                FlashcardView(
                    front = currentCard.front,
                    back = currentCard.back,
                    hint = currentCard.hint,
                    isFlipped = isFlipped,
                    onFlip = { isFlipped = !isFlipped }
                )

                Spacer(modifier = Modifier.weight(1f))

                if (isFlipped) {
                    RatingBar(
                        intervals = previewIntervals,
                        onRate = { rating ->
                            val reviewResult = scheduler.review(currentCard, rating)
                            onCardReviewed(reviewResult.card, rating)
                            isFlipped = false
                            currentIndex++
                        },
                        modifier = Modifier.padding(bottom = 16.dp)
                    )
                } else {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 28.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "Tap card to reveal answer and ratings",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.outline
                        )
                    }
                }
            }
        }
    }
}
