package com.medha.companion.data.model

import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.UUID

@Serializable
data class Deck(
    val id: String = generateId(),
    val name: String,
    val description: String? = null,
    val colorHex: String = "#3B82F6",
    val icon: String = "rectangle.stack",
    val isNotesDefault: Boolean = false,
    val presetId: String? = null,
    val createdAt: String = Instant.now().toString(),
    val updatedAt: String = Instant.now().toString()
) {
    companion object {
        const val NOTES_DEFAULT_ID = "deck-notes-default"

        fun generateId(): String = "deck-${UUID.randomUUID()}"
    }
}
