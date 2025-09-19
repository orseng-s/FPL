package com.example.fplnotifier

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.time.OffsetDateTime

private const val API_URL = "https://fantasy.premierleague.com/api/bootstrap-static/"

typealias JsonFetcher = suspend (String) -> String

class FplApiRepository(
    private val fetcher: JsonFetcher = { url -> defaultFetch(url) }
) {
    suspend fun getUpcomingDeadlines(now: Instant = Instant.now()): List<GameweekDeadline> {
        val payload = fetcher(API_URL)
        val root = JSONObject(payload)
        val events = root.optJSONArray("events") ?: JSONArray()
        val upcoming = mutableListOf<GameweekDeadline>()
        for (i in 0 until events.length()) {
            val event = events.optJSONObject(i) ?: continue
            val deadlineStr = event.optString("deadline_time", null) ?: continue
            val deadline = try {
                parseDeadline(deadlineStr)
            } catch (ex: Exception) {
                continue
            }
            if (!deadline.isAfter(now)) {
                continue
            }
            val id = event.optInt("id", -1)
            if (id <= 0) continue
            val name = event.optString("name", event.optString("event", "Gameweek"))
            upcoming += GameweekDeadline(
                eventId = id,
                name = name,
                deadline = deadline,
            )
        }
        return upcoming.sortedBy { it.deadline }
    }
}

internal fun parseDeadline(raw: String): Instant {
    return try {
        OffsetDateTime.parse(raw).toInstant()
    } catch (ex: Exception) {
        val normalized = if (raw.endsWith("Z", ignoreCase = true)) {
            raw.dropLast(1) + "+00:00"
        } else {
            raw
        }
        OffsetDateTime.parse(normalized).toInstant()
    }
}

private suspend fun defaultFetch(url: String): String = withContext(Dispatchers.IO) {
    val connection = URL(url).openConnection() as HttpURLConnection
    connection.requestMethod = "GET"
    connection.connectTimeout = 10_000
    connection.readTimeout = 10_000
    try {
        val stream = connection.inputStream
        BufferedReader(InputStreamReader(stream)).use { reader ->
            reader.readText()
        }
    } finally {
        connection.disconnect()
    }
}
