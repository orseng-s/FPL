# FPL Deadline Notifier

This project provides a small command-line application that reminds you of
upcoming Fantasy Premier League (FPL) deadlines. It polls the public FPL API,
calculates the next gameweek deadline, and sends a push notification via
[Pushover](https://pushover.net/) two hours before the deadline by default.

## Features

- Fetches official FPL gameweek deadlines from the public API.
- Schedules a single notification per gameweek with a configurable lead time.
- Uses [Pushover](https://pushover.net/) for cross-platform push notifications.
- Supports custom notification sounds, device targeting, and message timezone.
- Includes a test mode to send the next upcoming deadline notification on-demand.

## Requirements

- Python 3.11 or newer
- A Pushover account, application token, and user key
- API access to the public FPL endpoints (no authentication required)
- Optional: [`tzdata`](https://pypi.org/project/tzdata/) if your operating system
  does not ship IANA timezone information (common on Windows servers)

## Installation

Create and activate a virtual environment (optional but recommended):

```bash
python -m venv .venv
source .venv/bin/activate
```

The application does not require any third-party Python packages. If you want to
run the unit tests you will need [pytest](https://pytest.org/) available in your
environment.

Copy the example environment file and populate it with your Pushover credentials:

```bash
cp .env.example .env
```

Edit `.env` and set the following values:

- `PUSHOVER_TOKEN`: The API token for your Pushover application.
- `PUSHOVER_USER_KEY`: Your personal Pushover user key.

## Usage

Once configured, run the notifier:

```bash
python -m fpl_notifier
```

The command keeps running and periodically checks the FPL API. It sleeps until
the next notification window is within range (two hours by default), sends a
single push notification, and then waits for the next gameweek.

### Command-line options

```
python -m fpl_notifier [--lead-hours 2] [--poll-minutes 30] [--timezone Europe/London]
                        [--sound magic] [--device iphone] [--priority 1] [--verbose]
                        [--send-test]
```

- `--lead-hours`: Number of hours before the deadline to send the notification.
- `--poll-minutes`: How frequently to refresh deadlines while waiting.
- `--timezone`: Timezone used when displaying the deadline in the notification.
- `--sound`: Optional Pushover sound name.
- `--device`: Target a specific registered device.
- `--priority`: Override the Pushover priority level.
- `--verbose`: Enable debug logging.
- `--send-test`: Send the next upcoming deadline notification immediately and exit.

### Example

Send a reminder four hours before each deadline, poll every 15 minutes, and show
the time in the UK timezone:

```bash
python -m fpl_notifier --lead-hours 4 --poll-minutes 15 --timezone Europe/London
```

### Running tests

```bash
pytest
```

## Extending

The code is structured around three main modules:

- `fpl_notifier.deadlines`: Fetches and parses deadlines from the FPL API.
- `fpl_notifier.notifier`: Contains the Pushover integration.
- `fpl_notifier.service`: Orchestrates polling and scheduling.

You can implement alternative notification channels by creating a class with a
`send(gameweek, lead_time)` method and passing it to
`DeadlineNotificationService`.

## Android companion app

The repository also includes a Kotlin-based Android application under
[`android-app/`](android-app/README.md). The app mirrors the CLI flags for lead
time, polling interval, and timezone configuration, stores preferences via Jetpack
DataStore, and schedules background reminders using WorkManager. Reminders are
delivered as native notifications that match the payload produced by the Python
notifier.

To enable reminders on Android:

1. Open the app and adjust the lead time, poll interval, or timezone as needed.
2. Toggle **Enable reminders**. Android 13+ will prompt for the notification
   permission.
3. Keep the app installed; WorkManager will continue polling the public FPL API
   and trigger reminders at the configured lead time.
