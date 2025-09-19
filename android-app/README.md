# FPL Notifier Android app

This module provides a native Android companion to the Python-based Fantasy Premier League notifier. The application mirrors the command line configuration flags and delivers reminders using the Android notification system.

## Features

* Configure the notification lead time (hours before the deadline), the polling interval (minutes between API refreshes) and the timezone used to display deadlines.
* Persist configuration through Jetpack DataStore so settings survive application restarts.
* Background worker built on WorkManager that mirrors the scheduling logic from the Python `DeadlineNotificationService`.
* Native notifications built with `NotificationCompat` that reuse the existing message format.
* Automatic pruning of previously sent reminders to avoid duplicate alerts.

## Enabling reminders

1. Launch the application and adjust the lead time, polling interval or timezone as required. Changes are saved automatically.
2. Toggle **Enable reminders**. On Android 13+ you will be prompted to allow the *POST_NOTIFICATIONS* permission.
3. Once enabled, the app immediately queues the background worker. The status banner at the bottom of the screen reflects whether reminders are active and shows the last notification that was sent.
4. To stop reminders, disable the toggle. This cancels the scheduled worker and clears any pending reminders.

## Testing

Run unit tests from the module root:

```bash
./gradlew test
```
