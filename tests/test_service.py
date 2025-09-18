from datetime import datetime, timedelta, timezone

import pytest

from fpl_notifier.deadlines import GameweekDeadline
from fpl_notifier.service import DeadlineNotificationService


class FakeNotifier:
    def __init__(self):
        self.sent = []

    def send(self, gameweek, lead_time):
        self.sent.append((gameweek, lead_time))


def make_deadline(event_id: int, days_ahead: float) -> GameweekDeadline:
    deadline = datetime(2024, 8, 1, tzinfo=timezone.utc) + timedelta(days=days_ahead)
    return GameweekDeadline(event_id=event_id, name=f"GW{event_id}", deadline=deadline)


def test_step_waits_until_within_poll_interval():
    notifier = FakeNotifier()
    now = datetime(2024, 7, 1, tzinfo=timezone.utc)
    deadlines = [make_deadline(1, 10)]

    def fetcher(now=None):
        return deadlines

    service = DeadlineNotificationService(
        notifier,
        lead_time=timedelta(hours=2),
        poll_interval=timedelta(hours=6),
        fetcher=fetcher,
    )

    sleep = service.step(now=now)
    assert sleep == pytest.approx(timedelta(hours=6).total_seconds())
    assert notifier.sent == []


def test_step_returns_wait_time_when_notification_is_close():
    notifier = FakeNotifier()
    now = datetime(2024, 7, 1, 12, 0, tzinfo=timezone.utc)
    deadline = datetime(2024, 7, 1, 15, 0, tzinfo=timezone.utc)
    deadlines = [GameweekDeadline(event_id=2, name="GW2", deadline=deadline)]

    def fetcher(now=None):
        return deadlines

    service = DeadlineNotificationService(
        notifier,
        lead_time=timedelta(hours=2),
        poll_interval=timedelta(hours=6),
        fetcher=fetcher,
    )

    sleep = service.step(now=now)
    assert sleep == pytest.approx(3600)  # notify at 13:00 UTC
    assert notifier.sent == []


def test_step_sends_notification_when_within_lead_time():
    notifier = FakeNotifier()
    now = datetime(2024, 7, 1, 14, 30, tzinfo=timezone.utc)
    deadline = datetime(2024, 7, 1, 16, 0, tzinfo=timezone.utc)
    deadlines = [GameweekDeadline(event_id=3, name="GW3", deadline=deadline)]

    def fetcher(now=None):
        return deadlines

    service = DeadlineNotificationService(
        notifier,
        lead_time=timedelta(hours=2),
        poll_interval=timedelta(hours=6),
        fetcher=fetcher,
    )

    sleep = service.step(now=now)
    assert sleep == pytest.approx(timedelta(hours=6).total_seconds())
    assert len(notifier.sent) == 1
    gw, lead = notifier.sent[0]
    assert gw.event_id == 3
    assert lead == timedelta(hours=2)


def test_step_does_not_send_duplicate_notifications():
    notifier = FakeNotifier()
    deadline = datetime(2024, 7, 1, 16, 0, tzinfo=timezone.utc)
    deadlines = [GameweekDeadline(event_id=4, name="GW4", deadline=deadline)]

    def fetcher(now=None):
        return deadlines

    service = DeadlineNotificationService(
        notifier,
        lead_time=timedelta(hours=2),
        poll_interval=timedelta(hours=6),
        fetcher=fetcher,
    )

    first_sleep = service.step(now=datetime(2024, 7, 1, 14, 30, tzinfo=timezone.utc))
    assert len(notifier.sent) == 1

    second_sleep = service.step(now=datetime(2024, 7, 1, 15, 0, tzinfo=timezone.utc))
    assert len(notifier.sent) == 1
    assert first_sleep == pytest.approx(timedelta(hours=6).total_seconds())
    assert second_sleep == pytest.approx(timedelta(hours=6).total_seconds())


def test_sent_cache_is_cleared_after_deadline():
    notifier = FakeNotifier()
    deadline = datetime(2024, 7, 1, 16, 0, tzinfo=timezone.utc)
    deadlines = [GameweekDeadline(event_id=5, name="GW5", deadline=deadline)]

    def fetcher(now=None):
        return deadlines

    service = DeadlineNotificationService(
        notifier,
        lead_time=timedelta(hours=2),
        poll_interval=timedelta(hours=6),
        fetcher=fetcher,
    )

    service.step(now=datetime(2024, 7, 1, 15, 30, tzinfo=timezone.utc))
    assert len(notifier.sent) == 1

    # After the deadline passes the cache is cleared and we could notify again
    next_sleep = service.step(now=datetime(2024, 7, 1, 17, 0, tzinfo=timezone.utc))
    assert next_sleep == pytest.approx(timedelta(hours=6).total_seconds())
    assert len(notifier.sent) == 1  # no new send until fetcher provides future deadline
