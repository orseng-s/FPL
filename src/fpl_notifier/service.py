"""High level orchestration for scheduling deadline notifications."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
import logging
import time
from typing import Callable, Dict, Optional

from .deadlines import GameweekDeadline, fetch_gameweek_deadlines

LOGGER = logging.getLogger(__name__)

SleepFunction = Callable[[float], None]
Fetcher = Callable[..., list[GameweekDeadline]]


class DeadlineNotificationService:
    """Continuously polls the FPL API and delivers notifications."""

    def __init__(
        self,
        notifier,
        *,
        lead_time: timedelta = timedelta(hours=2),
        poll_interval: timedelta = timedelta(hours=6),
        fetcher: Fetcher = fetch_gameweek_deadlines,
        sleep_func: SleepFunction = time.sleep,
    ) -> None:
        if lead_time <= timedelta(0):
            raise ValueError("lead_time must be positive")
        if poll_interval <= timedelta(0):
            raise ValueError("poll_interval must be positive")

        self.notifier = notifier
        self.lead_time = lead_time
        self.poll_interval = poll_interval
        self.fetcher = fetcher
        self.sleep = sleep_func
        self._sent: Dict[int, datetime] = {}

    def _prune_sent(self, now: datetime) -> None:
        for event_id, deadline in list(self._sent.items()):
            expiry = deadline + self.poll_interval
            if now >= expiry:
                LOGGER.debug("Removing expired notification cache for GW %s", event_id)
                del self._sent[event_id]

    def _get_now(self) -> datetime:
        return datetime.now(timezone.utc)

    def step(self, *, now: Optional[datetime] = None) -> float:
        """Perform a single scheduling step and return the suggested sleep time."""

        raw_now = now or self._get_now()
        if raw_now.tzinfo is None:
            now = raw_now.replace(tzinfo=timezone.utc)
        else:
            now = raw_now.astimezone(timezone.utc)
        LOGGER.debug("Scheduler step at %s", now.isoformat())
        self._prune_sent(now)

        try:
            deadlines = self.fetcher(now=now)
        except Exception as exc:  # pragma: no cover - defensive
            LOGGER.error("Failed to fetch deadlines: %s", exc, exc_info=True)
            return self.poll_interval.total_seconds()

        if not deadlines:
            LOGGER.info("No upcoming deadlines. Sleeping for %s", self.poll_interval)
            return self.poll_interval.total_seconds()

        upcoming = deadlines[0]
        if upcoming.event_id in self._sent:
            LOGGER.debug(
                "Already notified about %s. Sleeping for %s", upcoming, self.poll_interval
            )
            return self.poll_interval.total_seconds()

        notify_at = upcoming.deadline - self.lead_time
        if notify_at <= now:
            LOGGER.info("Within lead time for %s. Sending notification immediately.", upcoming)
            self._deliver(upcoming)
            return self.poll_interval.total_seconds()

        wait_seconds = (notify_at - now).total_seconds()
        if wait_seconds > self.poll_interval.total_seconds():
            LOGGER.debug(
                "Notification is %.2f hours away; refreshing after %s",
                wait_seconds / 3600.0,
                self.poll_interval,
            )
            return self.poll_interval.total_seconds()

        LOGGER.info(
            "Scheduling notification for %s in %.1f minutes",
            upcoming,
            wait_seconds / 60.0,
        )
        return max(wait_seconds, 0.0)

    def _deliver(self, gameweek: GameweekDeadline) -> None:
        try:
            self.notifier.send(gameweek, self.lead_time)
            self._sent[gameweek.event_id] = gameweek.deadline
        except Exception as exc:  # pragma: no cover - defensive
            LOGGER.error("Failed to send notification: %s", exc, exc_info=True)

    def run(self) -> None:
        LOGGER.info("Starting deadline notification service")
        try:
            while True:
                sleep_for = self.step()
                if sleep_for > 0:
                    LOGGER.debug("Sleeping for %.2f seconds", sleep_for)
                    self.sleep(sleep_for)
        except KeyboardInterrupt:  # pragma: no cover - manual interrupt
            LOGGER.info("Shutting down notification service")
