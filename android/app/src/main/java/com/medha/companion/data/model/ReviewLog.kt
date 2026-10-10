package com.medha.companion.data.model

import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class ReviewLog(
    val id: String = generateId(),
    val cardId: String,
    val rating: Int,
    val state: String = "review",
    val elapsedDays: Int = 0,
    val scheduledDays: Int = 0,
    val reviewTime: String = "2026-10-10T00:00:00Z"
) {
    companion object {
        fun generateId(): String = "rev-${UUID.randomUUID()}"
    }
}
