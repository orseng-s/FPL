package com.example.fplnotifier

import android.app.Application

class FplNotifierApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        NotificationHelper.ensureChannel(this)
    }
}
