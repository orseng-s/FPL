package com.example.fplnotifier

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.first
import org.json.JSONArray
import org.json.JSONObject
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private val Context.reminderDataStore: DataStore<Preferences> by preferencesDataStore(name = "deadline_cache")

private val KEY_SENT = stringPreferencesKey("sent_reminders")
private val KEY_LAST_NOTIFICATION = stringPreferencesKey("last_notification")

class ReminderRepository(private val context: Context) {
    private val dataStore = context.reminderDataStore

    data class SentReminder(val eventId: Int, val deadline: Instant)

    val lastNotification: Flow<String?> = dataStore.data.map { prefs ->
        prefs[KEY_LAST_NOTIFICATION]
    }

    suspend fun getSentReminders(): List<SentReminder> {
        val prefs = dataStore.data.first()
        val raw = prefs[KEY_SENT] ?: return emptyList()
        val array = JSONArray(raw)
        val reminders = mutableListOf<SentReminder>()
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            val eventId = obj.optInt("eventId", -1)
            val deadlineStr = obj.optString("deadline", null) ?: continue
            if (eventId <= 0) continue
            val deadline = try {
                Instant.parse(deadlineStr)
            } catch (ex: Exception) {
                continue
            }
            reminders += SentReminder(eventId, deadline)
        }
        return reminders
    }

    suspend fun saveSentReminders(reminders: List<SentReminder>) {
        val array = JSONArray()
        reminders.forEach { reminder ->
            val obj = JSONObject()
            obj.put("eventId", reminder.eventId)
            obj.put("deadline", reminder.deadline.toString())
            array.put(obj)
        }
        dataStore.edit { prefs ->
            if (reminders.isEmpty()) {
                prefs.remove(KEY_SENT)
            } else {
                prefs[KEY_SENT] = array.toString()
            }
        }
    }

    suspend fun recordNotification(gameweek: GameweekDeadline, zoneId: ZoneId) {
        val formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm z")
        val message = buildString {
            append("Sent reminder for ")
            append(gameweek.name)
            append(" (GW ")
            append(gameweek.eventId)
            append(") at ")
            append(gameweek.deadlineIn(zoneId).format(formatter))
        }
        dataStore.edit { prefs ->
            prefs[KEY_LAST_NOTIFICATION] = message
        }
    }

    suspend fun clearLastNotification() {
        dataStore.edit { prefs ->
            prefs.remove(KEY_LAST_NOTIFICATION)
        }
    }

    fun prune(reminders: List<SentReminder>, now: Instant, pollInterval: Duration): List<SentReminder> {
        return reminders.filter { reminder ->
            now.isBefore(reminder.deadline.plus(pollInterval))
        }
    }
}
