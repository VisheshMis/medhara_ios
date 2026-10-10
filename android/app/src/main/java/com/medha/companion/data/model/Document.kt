package com.medha.companion.data.model

import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class Document(
    val id: String = generateId(),
    val notebookId: String,
    val parentId: String? = null,
    val title: String,
    val icon: String? = "doc",
    val isFolder: Boolean = false,
    val sortOrder: Int = 0,
    val isPinned: Boolean = false,
    val createdAt: String = "2026-10-10T00:00:00Z",
    val updatedAt: String = "2026-10-10T00:00:00Z"
) {
    companion object {
        fun generateId(): String = "doc-${UUID.randomUUID()}"
    }
}
