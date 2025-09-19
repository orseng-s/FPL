package com.example.fplnotifier

import java.time.Instant
import java.time.temporal.ChronoUnit
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FplApiRepositoryTest {

    @Test
    fun `parses upcoming deadlines and sorts by date`() = runTest {
        val now = Instant.parse("2024-08-10T10:00:00Z")
        val json = """
            {
              "events": [
                {"id": 2, "name": "Gameweek 2", "deadline_time": "2024-08-19T17:30:00Z"},
                {"id": 1, "name": "Gameweek 1", "deadline_time": "2024-08-16T17:30:00Z"}
              ]
            }
        """.trimIndent()
        val repository = FplApiRepository { json }

        val deadlines = repository.getUpcomingDeadlines(now)

        assertEquals(2, deadlines.size)
        assertEquals(1, deadlines.first().eventId)
        assertTrue(deadlines.first().deadline.isAfter(now))
        assertTrue(deadlines[1].deadline.isAfter(deadlines.first().deadline))
    }

    @Test
    fun `filters past deadlines and invalid entries`() = runTest {
        val now = Instant.parse("2024-08-20T10:00:00Z")
        val json = """
            {
              "events": [
                {"id": 1, "name": "Gameweek 1", "deadline_time": "2024-08-16T17:30:00Z"},
                {"id": 2, "name": "Gameweek 2", "deadline_time": "2024-08-22T17:30:00Z"},
                {"id": 3, "name": "Broken", "deadline_time": null}
              ]
            }
        """.trimIndent()
        val repository = FplApiRepository { json }

        val deadlines = repository.getUpcomingDeadlines(now)

        assertEquals(1, deadlines.size)
        assertEquals(2, deadlines.first().eventId)
        assertEquals("Gameweek 2", deadlines.first().name)
    }

    @Test
    fun `parseDeadline handles trailing Z`() {
        val instant = parseDeadline("2024-08-16T18:30:00Z")
        assertEquals(0, ChronoUnit.SECONDS.between(
            Instant.parse("2024-08-16T18:30:00Z"),
            instant
        ))
    }
}
