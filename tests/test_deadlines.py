from datetime import datetime, timezone

from fpl_notifier.deadlines import GameweekDeadline, fetch_gameweek_deadlines, get_next_gameweek_deadline, parse_deadline


class DummyFetcher:
    def __init__(self, payload):
        self.payload = payload
        self.calls = 0

    def __call__(self, url, timeout):
        self.calls += 1
        return self.payload


def test_parse_deadline_handles_z_suffix():
    parsed = parse_deadline("2024-08-16T18:30:00Z")
    assert parsed.tzinfo is not None
    assert parsed == datetime(2024, 8, 16, 18, 30, tzinfo=timezone.utc)


def test_fetch_gameweek_deadlines_filters_past_events():
    payload = {
        "events": [
            {
                "id": 1,
                "name": "Gameweek 1",
                "deadline_time": "2024-08-10T10:00:00Z",
            },
            {
                "id": 2,
                "name": "Gameweek 2",
                "deadline_time": "2024-08-20T10:00:00Z",
            },
        ]
    }
    fetcher = DummyFetcher(payload)
    now = datetime(2024, 8, 15, tzinfo=timezone.utc)

    deadlines = fetch_gameweek_deadlines(fetch_json=fetcher, now=now)
    assert [d.event_id for d in deadlines] == [2]
    assert fetcher.calls == 1


def test_get_next_gameweek_deadline_returns_none_when_empty():
    payload = {"events": []}
    fetcher = DummyFetcher(payload)

    assert get_next_gameweek_deadline(fetch_json=fetcher) is None


def test_get_next_gameweek_deadline_returns_first_upcoming():
    payload = {
        "events": [
            {
                "id": 1,
                "name": "Gameweek 1",
                "deadline_time": "2024-08-10T10:00:00Z",
            },
            {
                "id": 2,
                "name": "Gameweek 2",
                "deadline_time": "2024-09-01T09:00:00Z",
            },
        ]
    }
    fetcher = DummyFetcher(payload)
    now = datetime(2024, 8, 1, tzinfo=timezone.utc)

    next_deadline = get_next_gameweek_deadline(fetch_json=fetcher, now=now)
    assert isinstance(next_deadline, GameweekDeadline)
    assert next_deadline.event_id == 1
