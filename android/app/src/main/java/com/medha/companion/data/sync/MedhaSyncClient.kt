package com.medha.companion.data.sync

import com.medha.companion.data.model.SyncChangeLog
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

data class RemoteChange(
    val cursor: Long,
    val deviceId: String,
    val entityType: String,
    val entityId: String,
    val operation: String,
    val data: String?,
    val timestamp: Long,
    val lamportClock: Long
)

data class PushResult(
    val success: Boolean,
    val acceptedThroughChangeId: Long,
    val serverCursor: Long,
    val serverLamport: Long,
    val error: String? = null
)

data class PullResult(
    val serverCursor: Long,
    val serverLamport: Long,
    val hasMore: Boolean,
    val changes: List<RemoteChange>,
    val error: String? = null
)

/**
 * Android Sync Client communicating with the Medha Sync Server delta protocol.
 */
open class MedhaSyncClient(
    val baseUrl: String = "http://10.0.2.2:8787",
    private val connectTimeoutMs: Int = 5000,
    private val readTimeoutMs: Int = 10000
) {

    open fun checkHealth(): Boolean {
        return try {
            val url = URL("$baseUrl/api/v1/health")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.connectTimeout = connectTimeoutMs
            conn.readTimeout = readTimeoutMs
            conn.responseCode == 200
        } catch (e: Exception) {
            false
        }
    }

    open fun push(deviceId: String, changes: List<SyncChangeLog>): PushResult {
        if (changes.isEmpty()) {
            return PushResult(success = true, acceptedThroughChangeId = 0, serverCursor = 0, serverLamport = 0)
        }

        return try {
            val url = URL("$baseUrl/api/v1/sync/push")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.connectTimeout = connectTimeoutMs
            conn.readTimeout = readTimeoutMs
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/json; charset=UTF-8")
            conn.setRequestProperty("X-Device-Id", deviceId)

            val body = JSONObject()
            body.put("deviceId", deviceId)
            val changesArray = JSONArray()
            for (ch in changes) {
                val item = JSONObject()
                item.put("changeId", ch.id)
                item.put("entityType", ch.entityType)
                item.put("entityId", ch.entityId)
                item.put("operation", ch.operation)
                item.put("payload", ch.data ?: JSONObject.NULL)
                item.put("timestamp", ch.timestamp)
                item.put("lamportClock", ch.lamportClock)
                changesArray.put(item)
            }
            body.put("changes", changesArray)

            OutputStreamWriter(conn.outputStream, "UTF-8").use { writer ->
                writer.write(body.toString())
                writer.flush()
            }

            val code = conn.responseCode
            if (code == 200) {
                val responseStr = conn.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(responseStr)
                PushResult(
                    success = json.optBoolean("success", true),
                    acceptedThroughChangeId = json.optLong("acceptedThroughChangeId", 0L),
                    serverCursor = json.optLong("serverCursor", 0L),
                    serverLamport = json.optLong("serverLamport", 0L)
                )
            } else {
                val errStr = conn.errorStream?.bufferedReader()?.use { it.readText() } ?: "HTTP $code"
                PushResult(
                    success = false,
                    acceptedThroughChangeId = 0L,
                    serverCursor = 0L,
                    serverLamport = 0L,
                    error = errStr
                )
            }
        } catch (e: Exception) {
            PushResult(
                success = false,
                acceptedThroughChangeId = 0L,
                serverCursor = 0L,
                serverLamport = 0L,
                error = e.message ?: "Network error"
            )
        }
    }

    open fun pull(sinceCursor: Long = 0L, limit: Int = 250): PullResult {
        return try {
            val url = URL("$baseUrl/api/v1/sync/pull?sinceCursor=$sinceCursor&limit=$limit")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.connectTimeout = connectTimeoutMs
            conn.readTimeout = readTimeoutMs
            conn.setRequestProperty("Accept", "application/json")

            val code = conn.responseCode
            if (code == 200) {
                val responseStr = conn.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(responseStr)
                val serverCursor = json.optLong("serverCursor", 0L)
                val serverLamport = json.optLong("serverLamport", 0L)
                val hasMore = json.optBoolean("hasMore", false)

                val changesArray = json.optJSONArray("changes") ?: JSONArray()
                val parsedChanges = mutableListOf<RemoteChange>()

                for (i in 0 until changesArray.length()) {
                    val obj = changesArray.getJSONObject(i)
                    parsedChanges.add(
                        RemoteChange(
                            cursor = obj.optLong("cursor", 0L),
                            deviceId = obj.optString("deviceId", ""),
                            entityType = obj.optString("entityType", ""),
                            entityId = obj.optString("entityId", ""),
                            operation = obj.optString("operation", "UPDATE"),
                            data = if (obj.isNull("data")) null else obj.getString("data"),
                            timestamp = obj.optLong("timestamp", 0L),
                            lamportClock = obj.optLong("lamportClock", 0L)
                        )
                    )
                }

                PullResult(
                    serverCursor = serverCursor,
                    serverLamport = serverLamport,
                    hasMore = hasMore,
                    changes = parsedChanges
                )
            } else {
                val errStr = conn.errorStream?.bufferedReader()?.use { it.readText() } ?: "HTTP $code"
                PullResult(
                    serverCursor = 0L,
                    serverLamport = 0L,
                    hasMore = false,
                    changes = emptyList(),
                    error = errStr
                )
            }
        } catch (e: Exception) {
            PullResult(
                serverCursor = 0L,
                serverLamport = 0L,
                hasMore = false,
                changes = emptyList(),
                error = e.message ?: "Network error"
            )
        }
    }
}
