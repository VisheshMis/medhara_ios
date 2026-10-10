package com.medha.companion.data.model

import kotlinx.serialization.Serializable

@Serializable
enum class SyncOperation(val rawValue: String) {
    INSERT("INSERT"),
    UPDATE("UPDATE"),
    DELETE("DELETE");

    companion object {
        fun fromString(op: String): SyncOperation =
            entries.firstOrNull { it.rawValue.equals(op, ignoreCase = true) } ?: INSERT
    }
}

@Serializable
data class SyncChangeLog(
    val id: Long = 0L,
    val entityType: String,
    val entityId: String,
    val operation: String,
    val data: String? = null,
    val timestamp: Long = System.currentTimeMillis(),
    val lamportClock: Long = 0L,
    val isSynced: Boolean = false
) {
    val syncOperation: SyncOperation
        get() = SyncOperation.fromString(operation)
}
