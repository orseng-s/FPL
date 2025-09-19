package com.example.fplnotifier

import android.content.Context
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import java.time.Duration
import java.util.concurrent.TimeUnit

object DeadlineScheduler {
    private const val UNIQUE_WORK_NAME = "fpl_deadline_worker"

    fun schedule(context: Context, delay: Duration) {
        val safeDelay = if (delay.isNegative) Duration.ZERO else delay
        val request = OneTimeWorkRequestBuilder<DeadlineWorker>()
            .setInitialDelay(safeDelay.toMillis(), TimeUnit.MILLISECONDS)
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            UNIQUE_WORK_NAME,
            ExistingWorkPolicy.REPLACE,
            request
        )
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(UNIQUE_WORK_NAME)
    }
}
