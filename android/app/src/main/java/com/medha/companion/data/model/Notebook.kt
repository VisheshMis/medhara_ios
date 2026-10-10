package com.medha.companion.data.model

import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class Notebook(
    val id: String = generateId(),
    val name: String,
    val icon: String? = "book.closed.fill",
    val sortOrder: Int = 0,
    val isArchived: Boolean = false,
    val updatedAt: String = "2026-10-10T00:00:00Z"
) {
    companion object {
        fun generateId(): String = "nb-${UUID.randomUUID()}"
    }
}
