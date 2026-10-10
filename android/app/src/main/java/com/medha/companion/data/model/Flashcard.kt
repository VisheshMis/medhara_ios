package com.medha.companion.data.model

import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
enum class FSRSState(val value: Int, val displayName: String) {
    NEW_CARD(0, "New"),
    LEARNING(1, "Learning"),
    REVIEW(2, "Review"),
    RELEARNING(3, "Relearning");

    companion object {
        fun fromInt(value: Int): FSRSState = entries.firstOrNull { it.value == value } ?: NEW_CARD
    }
}

@Serializable
enum class FSRSRating(val value: Int, val displayName: String) {
    AGAIN(1, "Again"),
    HARD(2, "Hard"),
    GOOD(3, "Good"),
    EASY(4, "Easy");

    companion object {
        fun fromInt(value: Int): FSRSRating = entries.firstOrNull { it.value == value } ?: GOOD
    }
}

@Serializable
enum class FlashcardType(val value: Int, val displayName: String) {
    STANDARD(0, "Standard"),
    IMAGE_OCCLUSION(1, "Image Occlusion");

    companion object {
        fun fromInt(value: Int): FlashcardType = entries.firstOrNull { it.value == value } ?: STANDARD
    }
}

@Serializable
enum class OcclusionMode(val value: Int, val displayName: String) {
    HIDE_ONE_REVEAL_ONE(0, "Hide One, Reveal One"),
    HIDE_ALL_REVEAL_ONE(1, "Hide All, Reveal One");

    companion object {
        fun fromInt(value: Int): OcclusionMode = entries.firstOrNull { it.value == value } ?: HIDE_ALL_REVEAL_ONE
    }
}

@Serializable
data class ImageOcclusionMask(
    val id: String = "mask-${UUID.randomUUID()}",
    val x: Double,
    val y: Double,
    val width: Double,
    val height: Double,
    val label: String? = null,
    val orderIndex: Int = 0
)

@Serializable
data class Flashcard(
    val id: String = generateId(),
    val docId: String,
    val notebookId: String,
    val front: String,
    val back: String,
    val sourceBlockId: String? = null,
    val hint: String? = null,
    val fsrsState: Int = 0,
    val stability: Double = 0.0,
    val difficulty: Double = 0.0,
    val elapsedDays: Int = 0,
    val scheduledDays: Int = 0,
    val reps: Int = 0,
    val lapses: Int = 0,
    val lastReview: String? = null,
    val due: String = "2026-10-10T00:00:00Z",
    val deckId: String? = "deck-notes-default",
    val isSuspended: Boolean? = false,
    val cardType: Int = 0,
    val imagePath: String? = null,
    val occlusionMasksData: String? = null,
    val activeMaskId: String? = null,
    val occlusionMode: Int = 1,
    val createdAt: String = "2026-10-10T00:00:00Z",
    val updatedAt: String = "2026-10-10T00:00:00Z"
) {
    val state: FSRSState
        get() = FSRSState.fromInt(fsrsState)

    val type: FlashcardType
        get() = FlashcardType.fromInt(cardType)

    val mode: OcclusionMode
        get() = OcclusionMode.fromInt(occlusionMode)

    val isEffectivelySuspended: Boolean
        get() = isSuspended == true

    val isDue: Boolean
        get() {
            if (isEffectivelySuspended) return false
            return try {
                !java.time.Instant.parse(due).isAfter(java.time.Instant.now())
            } catch (e: Exception) {
                true
            }
        }

    companion object {
        fun generateId(): String = "fc-${UUID.randomUUID()}"
    }
}
