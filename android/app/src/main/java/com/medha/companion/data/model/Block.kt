package com.medha.companion.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
enum class BlockType(val typeName: String) {
    @SerialName("doc")
    DOC("doc"),

    @SerialName("inkDoc")
    INK_DOC("inkDoc"),

    @SerialName("heading1")
    HEADING1("heading1"),

    @SerialName("heading2")
    HEADING2("heading2"),

    @SerialName("heading3")
    HEADING3("heading3"),

    @SerialName("paragraph")
    PARAGRAPH("paragraph"),

    @SerialName("bulletList")
    BULLET_LIST("bulletList"),

    @SerialName("taskList")
    TASK_LIST("taskList"),

    @SerialName("codeBlock")
    CODE_BLOCK("codeBlock"),

    @SerialName("quote")
    QUOTE("quote"),

    @SerialName("callout")
    CALLOUT("callout"),

    @SerialName("blockRef")
    BLOCK_REF("blockRef"),

    @SerialName("toggle")
    TOGGLE("toggle"),

    @SerialName("table")
    TABLE("table");

    companion object {
        fun fromString(str: String): BlockType =
            entries.firstOrNull { it.typeName.equals(str, ignoreCase = true) } ?: PARAGRAPH
    }
}

@Serializable
data class Block(
    val id: String = generateId(),
    val rootDocId: String,
    val parentId: String? = null,
    val type: BlockType = BlockType.PARAGRAPH,
    val content: String = "",
    val sortOrder: Int = 0,
    val isCompleted: Boolean? = false,
    val refTargetId: String? = null,
    val createdAt: String = "2026-10-10T00:00:00Z",
    val updatedAt: String = "2026-10-10T00:00:00Z",
    val notebookId: String? = null,
    val canvasMode: String? = "a4Pages",
    val isCollapsed: Boolean? = false,
    val icon: String? = null,
    val colorTint: String? = null,
    val verifiedAt: String? = null,
    val verifiedExpiresAt: String? = null,
    val verifiedBy: String? = null,
    val isLocked: Boolean? = false,
    val pinnedPropertiesData: String? = null
) {
    val isDocument: Boolean
        get() = type == BlockType.DOC || type == BlockType.INK_DOC

    val isHeading: Boolean
        get() = type == BlockType.HEADING1 || type == BlockType.HEADING2 || type == BlockType.HEADING3

    val isVerified: Boolean
        get() {
            val expires = verifiedExpiresAt ?: return false
            return try {
                java.time.Instant.parse(expires).isAfter(java.time.Instant.now())
            } catch (e: Exception) {
                false
            }
        }

    companion object {
        fun generateId(): String = "b-${UUID.randomUUID()}"
    }
}
