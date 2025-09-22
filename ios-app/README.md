# FplNotifier for iOS

The iOS client mirrors the Android Fantasy Premier League notifier experience. It offers a SwiftUI configuration screen where you can:

- Enable or disable reminder notifications.
- Choose how many hours before kickoff the reminder should fire.
- Pick how often the background poll should check for new deadlines.
- Select the timezone used when displaying deadlines and notifications.

Under the hood the app downloads `https://fantasy.premierleague.com/api/bootstrap-static/`, parses the upcoming gameweek deadlines, and schedules local notifications that match the Android copy.

## Project layout

```
ios-app/
  FplNotifier.xcodeproj      # Xcode project targeting iOS 15+
  FplNotifier/               # Application sources (SwiftUI UI, data layer, scheduler)
  Tests/FplNotifierTests/    # XCTest targets and JSON fixtures
```

User preferences and last-notified gameweeks are persisted with `UserDefaults`, so the SwiftUI UI and background scheduler stay in sync across launches.

## Requirements & setup

1. Open `ios-app/FplNotifier.xcodeproj` in Xcode 15 or newer.
2. Select the *FplNotifier* scheme and choose an iOS 15+ simulator or a provisioned device.
3. Build & run the project (`⌘R`).

### Notifications

- The first time you toggle "Enable reminders" the app will prompt for notification permissions via `UNUserNotificationCenter`.
- Local notifications use the default sound and replicate the Android title/body copy, including the selected lead time and timezone.
- If permissions are denied the toggle is reset and no background work is scheduled.

### Background refresh

- The scheduler uses an internal `Task` loop to poll the Fantasy Premier League API on the configured interval.
- For reliable delivery on device you should enable *Background App Refresh* in **Settings → General → Background App Refresh** so the app can wake up when suspended.
- When notifications are disabled the scheduler cancels outstanding work and clears the "last notification" status, matching the Android behavior.

## Running unit tests

The project includes XCTest coverage for the JSON parsing logic. From the repository root you can run:

```bash
xcodebuild test -project ios-app/FplNotifier.xcodeproj -scheme FplNotifier -destination 'platform=iOS Simulator,name=iPhone 14'
```

This exercises the parsing flow with bundled fixtures under `ios-app/Tests/FplNotifierTests/Fixtures`.
