"""Command-line entry point for the FPL deadline notifier."""

from __future__ import annotations

import argparse
import logging
import os
from datetime import timedelta
from typing import Optional

from zoneinfo import ZoneInfo

from .notifier import PushoverNotifier
from .service import DeadlineNotificationService


def _configure_logging(verbose: bool) -> None:
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(level=level, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")


def _parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Send push notifications before FPL deadlines")
    parser.add_argument("--lead-hours", type=float, default=2.0, help="How many hours before the deadline to notify")
    parser.add_argument(
        "--poll-minutes",
        type=float,
        default=30.0,
        help="How frequently to refresh the FPL API while waiting for the next deadline",
    )
    parser.add_argument(
        "--timezone",
        default="UTC",
        help="Timezone name (IANA) used when displaying the deadline time in the notification",
    )
    parser.add_argument(
        "--sound",
        default=None,
        help="Optional Pushover notification sound",
    )
    parser.add_argument("--device", default=None, help="Optional Pushover device name")
    parser.add_argument(
        "--priority",
        type=int,
        default=None,
        help="Optional Pushover priority override",
    )
    parser.add_argument("--verbose", action="store_true", help="Enable verbose logging")
    parser.add_argument(
        "--send-test",
        action="store_true",
        help="Send a test notification immediately and exit",
    )
    return parser.parse_args(argv)


def _load_env_file(path: str = ".env") -> None:
    if not os.path.exists(path):
        return
    try:
        with open(path, "r", encoding="utf-8") as handle:
            for line in handle:
                striped = line.strip()
                if not striped or striped.startswith("#"):
                    continue
                if "=" not in striped:
                    continue
                key, value = striped.split("=", 1)
                os.environ.setdefault(key.strip(), value.strip())
    except OSError:
        pass


def main(argv: Optional[list[str]] = None) -> None:
    _load_env_file()

    args = _parse_args(argv)
    _configure_logging(args.verbose)

    token = os.environ.get("PUSHOVER_TOKEN")
    user_key = os.environ.get("PUSHOVER_USER_KEY")
    if not token or not user_key:
        raise SystemExit(
            "PUSHOVER_TOKEN and PUSHOVER_USER_KEY environment variables are required for Pushover"
        )

    try:
        tz = ZoneInfo(args.timezone)
    except Exception as exc:  # pragma: no cover - user configuration issue
        raise SystemExit(f"Invalid timezone '{args.timezone}': {exc}")

    notifier = PushoverNotifier(
        token=token,
        user_key=user_key,
        timezone=tz,
        sound=args.sound,
        device=args.device,
        priority=args.priority,
    )

    lead_time = timedelta(hours=args.lead_hours)
    poll_interval = timedelta(minutes=args.poll_minutes)
    service = DeadlineNotificationService(
        notifier,
        lead_time=lead_time,
        poll_interval=poll_interval,
    )

    if args.send_test:
        from .deadlines import get_next_gameweek_deadline

        upcoming = get_next_gameweek_deadline()
        if not upcoming:
            raise SystemExit("No upcoming deadlines found")
        notifier.send(upcoming, lead_time)
        return

    service.run()


if __name__ == "__main__":  # pragma: no cover - CLI entry point
    main()
