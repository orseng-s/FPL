package com.example.fplnotifier

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

    private val leadFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm z")

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.app_name),
                NotificationManager.IMPORTANCE_DEFAULT
            )
            channel.description = "Upcoming Fantasy Premier League deadlines"
            manager.createNotificationChannel(channel)
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

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        NotificationManagerCompat.from(context).notify(gameweek.eventId, notification)
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
}
