package com.example.fplnotifier

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import java.text.DecimalFormat
import java.time.Duration
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch

data class UiState(
    val leadHours: String = "2",
    val pollMinutes: String = "360",
    val timezone: String = java.time.ZoneId.systemDefault().id,
    val notificationsEnabled: Boolean = false,
    val draftNotificationsEnabled: Boolean = false,
    val statusText: String = "",
    val lastNotification: String? = null,
)

class MainViewModel(
    application: Application,
    private val settingsRepository: SettingsRepository,
    private val reminderRepository: ReminderRepository,
) : AndroidViewModel(application) {

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val decimalFormat = DecimalFormat("0.##")

    init {
        viewModelScope.launch {
            combine(settingsRepository.settings, reminderRepository.lastNotification) { settings, last ->
                val enabledTypes = mutableListOf<String>().apply {
                    if (settings.notificationsEnabled) {
                        add(application.getString(R.string.status_type_standard))
                    }
                    if (settings.draftNotificationsEnabled) {
                        add(application.getString(R.string.status_type_draft))
                    }
                }
                val status = if (enabledTypes.isEmpty()) {
                    application.getString(R.string.notifications_disabled)
                } else {
                    application.getString(
                        R.string.notifications_enabled_types,
                        enabledTypes.joinToString(", ")
                    )
                }
                UiState(
                    leadHours = decimalFormat.format(settings.leadHours),
                    pollMinutes = settings.pollMinutes.toString(),
                    timezone = settings.timezoneId,
                    notificationsEnabled = settings.notificationsEnabled,
                    draftNotificationsEnabled = settings.draftNotificationsEnabled,
                    statusText = status,
                    lastNotification = last,
                )
            }.collect { ui ->
                _state.value = ui
            }
        }
    }

    fun onLeadHoursChanged(value: Double) {
        viewModelScope.launch {
            settingsRepository.updateLeadHours(value)
            restartIfNeeded()
        }
    }

    fun onPollMinutesChanged(value: Long) {
        viewModelScope.launch {
            settingsRepository.updatePollMinutes(value)
            restartIfNeeded()
        }
    }

    fun onTimezoneChanged(zoneId: String) {
        viewModelScope.launch {
            settingsRepository.updateTimezone(zoneId)
            restartIfNeeded()
        }
    }

    fun onNotificationsToggled(enabled: Boolean) {
        viewModelScope.launch {
            settingsRepository.setNotificationsEnabled(enabled)
            if (enabled || _state.value.draftNotificationsEnabled) {
                DeadlineScheduler.schedule(getApplication(), Duration.ZERO)
            } else {
                DeadlineScheduler.cancel(getApplication())
            }
        }
    }

    fun onDraftNotificationsToggled(enabled: Boolean) {
        viewModelScope.launch {
            settingsRepository.setDraftNotificationsEnabled(enabled)
            if (enabled || _state.value.notificationsEnabled) {
                DeadlineScheduler.schedule(getApplication(), Duration.ZERO)
            } else {
                DeadlineScheduler.cancel(getApplication())
            }
        }
    }

    private suspend fun restartIfNeeded() {
        if (_state.value.notificationsEnabled || _state.value.draftNotificationsEnabled) {
            DeadlineScheduler.schedule(getApplication(), Duration.ZERO)
        }
    }
}
