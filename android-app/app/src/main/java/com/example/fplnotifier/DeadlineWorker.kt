package com.example.fplnotifier

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import kotlin.math.roundToLong
import kotlinx.coroutines.flow.first

class DeadlineWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : CoroutineWorker(appContext, workerParams) {

    private val settingsRepository = SettingsRepository(appContext)
    private val reminderRepository = ReminderRepository(appContext)
    private val apiRepository = FplApiRepository()

    override suspend fun doWork(): Result {
        val settings = settingsRepository.settings.first()
        if (!settings.notificationsEnabled) {
            reminderRepository.clearLastNotification()
            DeadlineScheduler.cancel(applicationContext)
            return Result.success()
        }

        val now = Instant.now()
        val pollDuration = Duration.ofMinutes(settings.pollMinutes)
        val leadDuration = Duration.ofMillis((settings.leadHours * 3600_000).roundToLong())
        val zoneId = runCatching { ZoneId.of(settings.timezoneId) }.getOrDefault(ZoneId.systemDefault())

        val sent = reminderRepository.getSentReminders()
        var cache = reminderRepository.prune(sent, now, pollDuration)

        val deadlines = try {
            apiRepository.getUpcomingDeadlines(now)
        } catch (ex: Exception) {
            reminderRepository.saveSentReminders(cache)
            DeadlineScheduler.schedule(applicationContext, pollDuration)
            return Result.success()
        }

        val upcoming = deadlines.firstOrNull()
        var nextDelay = pollDuration

        if (upcoming == null) {
            reminderRepository.saveSentReminders(cache)
        } else {
            val alreadySent = cache.any { it.eventId == upcoming.eventId }
            val notifyAt = upcoming.deadline.minus(leadDuration)
            if (!notifyAt.isAfter(now)) {
                if (!alreadySent) {
                    NotificationHelper.sendNotification(applicationContext, upcoming, leadDuration, zoneId)
                    cache = cache + ReminderRepository.SentReminder(upcoming.eventId, upcoming.deadline)
                    reminderRepository.recordNotification(upcoming, zoneId)
                }
                nextDelay = pollDuration
                reminderRepository.saveSentReminders(cache)
            } else {
                val waitSeconds = Duration.between(now, notifyAt)
                nextDelay = if (waitSeconds > pollDuration) pollDuration else waitSeconds
                reminderRepository.saveSentReminders(cache)
            }
        }

        DeadlineScheduler.schedule(applicationContext, nextDelay)
        return Result.success()
    }
}
