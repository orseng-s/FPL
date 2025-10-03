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
        if (!settings.notificationsEnabled && !settings.draftNotificationsEnabled) {
            reminderRepository.clearLastNotification()
            DeadlineScheduler.cancel(applicationContext)
            return Result.success()
        }

        val now = Instant.now()
        val pollDuration = Duration.ofMinutes(settings.pollMinutes)
        val leadDuration = Duration.ofMillis((settings.leadHours * 3600_000).roundToLong())
        val draftLeadDuration = Duration.ofHours(24)
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

        if (upcoming != null) {
            data class ReminderCandidate(
                val type: ReminderRepository.ReminderType,
                val notifyAt: Instant,
            )

            val candidates = mutableListOf<ReminderCandidate>()
            if (settings.notificationsEnabled) {
                candidates += ReminderCandidate(
                    ReminderRepository.ReminderType.STANDARD,
                    upcoming.deadline.minus(leadDuration)
                )
            }
            if (settings.draftNotificationsEnabled) {
                candidates += ReminderCandidate(
                    ReminderRepository.ReminderType.DRAFT,
                    upcoming.deadline.minus(draftLeadDuration)
                )
            }

            fun isSent(type: ReminderRepository.ReminderType): Boolean {
                return cache.any { it.eventId == upcoming.eventId && it.type == type }
            }

            val dueCandidate = candidates
                .filter { !isSent(it.type) && !it.notifyAt.isAfter(now) }
                .minByOrNull { it.notifyAt }

            if (dueCandidate != null) {
                when (dueCandidate.type) {
                    ReminderRepository.ReminderType.STANDARD -> {
                        NotificationHelper.sendNotification(applicationContext, upcoming, leadDuration, zoneId)
                    }
                    ReminderRepository.ReminderType.DRAFT -> {
                        NotificationHelper.sendDraftNotification(applicationContext, upcoming, zoneId)
                    }
                }
                cache = cache + ReminderRepository.SentReminder(
                    upcoming.eventId,
                    upcoming.deadline,
                    dueCandidate.type
                )
                reminderRepository.recordNotification(upcoming, zoneId, dueCandidate.type)
            }

            val remainingCandidates = candidates.filterNot { candidate ->
                cache.any { it.eventId == upcoming.eventId && it.type == candidate.type }
            }

            if (remainingCandidates.isNotEmpty()) {
                val additionalDue = remainingCandidates.any { !it.notifyAt.isAfter(now) }
                nextDelay = if (additionalDue) {
                    Duration.ZERO
                } else {
                    val soonest = remainingCandidates
                        .map { Duration.between(now, it.notifyAt) }
                        .map { if (it.isNegative) Duration.ZERO else it }
                        .minOrNull()
                    when {
                        soonest == null -> pollDuration
                        soonest > pollDuration -> pollDuration
                        else -> soonest
                    }
                }
            }
        }

        reminderRepository.saveSentReminders(cache)

        DeadlineScheduler.schedule(applicationContext, nextDelay)
        return Result.success()
    }
}
