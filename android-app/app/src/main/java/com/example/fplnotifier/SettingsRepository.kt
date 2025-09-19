package com.example.fplnotifier

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.doublePreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.time.ZoneId

private val Context.settingsDataStore: DataStore<Preferences> by preferencesDataStore(name = "user_settings")

private val KEY_LEAD_HOURS = doublePreferencesKey("lead_hours")
private val KEY_POLL_MINUTES = longPreferencesKey("poll_minutes")
private val KEY_TIMEZONE = stringPreferencesKey("timezone")
private val KEY_NOTIFICATIONS_ENABLED = booleanPreferencesKey("notifications_enabled")

data class UserSettings(
    val leadHours: Double,
    val pollMinutes: Long,
    val timezoneId: String,
    val notificationsEnabled: Boolean,
)

class SettingsRepository(private val context: Context) {
    private val dataStore = context.settingsDataStore

    val settings: Flow<UserSettings> = dataStore.data.map { prefs ->
        val defaultTz = ZoneId.systemDefault().id
        UserSettings(
            leadHours = prefs[KEY_LEAD_HOURS] ?: 2.0,
            pollMinutes = prefs[KEY_POLL_MINUTES] ?: 360,
            timezoneId = prefs[KEY_TIMEZONE] ?: defaultTz,
            notificationsEnabled = prefs[KEY_NOTIFICATIONS_ENABLED] ?: false,
        )
    }

    suspend fun updateLeadHours(value: Double) {
        dataStore.edit { prefs ->
            prefs[KEY_LEAD_HOURS] = value.coerceAtLeast(0.1)
        }
    }

    suspend fun updatePollMinutes(value: Long) {
        dataStore.edit { prefs ->
            prefs[KEY_POLL_MINUTES] = value.coerceAtLeast(1L)
        }
    }

    suspend fun updateTimezone(zoneId: String) {
        dataStore.edit { prefs ->
            prefs[KEY_TIMEZONE] = zoneId
        }
    }

    suspend fun setNotificationsEnabled(enabled: Boolean) {
        dataStore.edit { prefs ->
            prefs[KEY_NOTIFICATIONS_ENABLED] = enabled
        }
    }
}
