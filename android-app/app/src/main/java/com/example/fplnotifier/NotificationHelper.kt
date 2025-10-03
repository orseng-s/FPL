package com.example.fplnotifier

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.time.Duration
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.math.abs

object NotificationHelper {
    const val CHANNEL_ID = "fpl_deadlines"
    const val DRAFT_CHANNEL_ID = "fpl_draft_deadlines"

    private const val STANDARD_NOTIFICATION_OFFSET = 1
    private const val DRAFT_NOTIFICATION_OFFSET = 2

    private val leadFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm z")

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val standardChannel = NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.app_name),
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Upcoming Fantasy Premier League deadlines"
                enableVibration(true)
            }
            val draftChannel = NotificationChannel(
                DRAFT_CHANNEL_ID,
                context.getString(R.string.app_name) + " Draft",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "FPL draft deadline reminders"
                enableVibration(true)
            }
            manager.createNotificationChannel(standardChannel)
            manager.createNotificationChannel(draftChannel)
        }
    }

    fun sendNotification(
        context: Context,
        gameweek: GameweekDeadline,
        leadTime: Duration,
        timezone: ZoneId,
    ) {
        ensureChannel(context)
        val formattedLead = formatLead(leadTime)
        val deadlineLocal = gameweek.deadlineIn(timezone).format(leadFormatter)
        val title = "FPL deadline in $formattedLead"
        val message = "${gameweek.name} (GW ${gameweek.eventId}) deadline at $deadlineLocal"

        val notification = buildNotification(context, CHANNEL_ID, title, message)

        NotificationManagerCompat.from(context)
            .notify(notificationId(gameweek.eventId, STANDARD_NOTIFICATION_OFFSET), notification)
    }

    fun sendDraftNotification(
        context: Context,
        gameweek: GameweekDeadline,
        timezone: ZoneId,
    ) {
        ensureChannel(context)
        val draftLock = gameweek.deadline.minus(Duration.ofHours(24))
        val deadlineLocal = gameweek.deadlineIn(timezone).format(leadFormatter)
        val draftLockLocal = draftLock.atZone(timezone).format(leadFormatter)
        val title = "Draft deadline approaching"
        val message = buildString {
            append("Draft transactions lock 24 hours before the FPL deadline. ")
            append(gameweek.name)
            append(" (GW ")
            append(gameweek.eventId)
            append(") draft window closes at ")
            append(draftLockLocal)
            append(", final deadline at ")
            append(deadlineLocal)
        }

        val notification = buildNotification(context, DRAFT_CHANNEL_ID, title, message)

        NotificationManagerCompat.from(context)
            .notify(notificationId(gameweek.eventId, DRAFT_NOTIFICATION_OFFSET), notification)
    }

    private fun formatLead(delta: Duration): String {
        val totalSeconds = abs(delta.seconds)
        if (totalSeconds < 60) {
            return "$totalSeconds seconds"
        }
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        val hours = minutes / 60
        val remainingMinutes = minutes % 60
        val parts = mutableListOf<String>()
        if (hours > 0) {
            parts += if (hours == 1L) "1 hour" else "$hours hours"
        }
        if (remainingMinutes > 0) {
            parts += if (remainingMinutes == 1L) "1 minute" else "$remainingMinutes minutes"
        }
        if (seconds > 0 && hours == 0L) {
            parts += if (seconds == 1L) "1 second" else "$seconds seconds"
        }
        return parts.joinToString(" and ")
    }

    private fun buildNotification(
        context: Context,
        channelId: String,
        title: String,
        message: String,
    ): Notification {
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(Notification.DEFAULT_ALL)
            .build()
    }

    private fun notificationId(eventId: Int, offset: Int): Int {
        return eventId * 10 + offset
    }
}
