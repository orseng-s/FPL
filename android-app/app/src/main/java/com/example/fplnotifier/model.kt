package com.example.fplnotifier

import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter

/** Represents a Fantasy Premier League gameweek deadline. */
data class GameweekDeadline(
    val eventId: Int,
    val name: String,
    val deadline: Instant,
) {
    fun deadlineIn(zoneId: ZoneId): ZonedDateTime = ZonedDateTime.ofInstant(deadline, zoneId)
}

object DeadlineFormatter {
    private val deadlineFormatter: DateTimeFormatter =
        DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm z")

    fun formatDeadline(deadline: GameweekDeadline, zoneId: ZoneId): String {
        return deadline.deadlineIn(zoneId).format(deadlineFormatter)
    }
}
