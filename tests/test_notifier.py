from datetime import datetime, timedelta, timezone

from fpl_notifier.deadlines import GameweekDeadline
from fpl_notifier.notifier import PushoverNotifier, _format_timedelta


def test_format_timedelta_human_readable():
    assert _format_timedelta(timedelta(seconds=45)) == "45 seconds"
    assert _format_timedelta(timedelta(minutes=1, seconds=30)) == "1 minute and 30 seconds"
    assert _format_timedelta(timedelta(hours=2, minutes=15)) == "2 hours and 15 minutes"


class DummyResponse:
    def __init__(self):
        self.data = None

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def read(self):
        return b"{\"status\":1}"

    def getcode(self):
        return 200


class DummyOpener:
    def __init__(self):
        self.last_request = None
        self.response = DummyResponse()

    def open(self, request_obj, timeout=0):
        self.last_request = request_obj
        return self.response


def test_pushover_notifier_builds_payload_and_posts():
    opener = DummyOpener()

    notifier = PushoverNotifier("token", "user", opener=opener)
    gameweek = GameweekDeadline(
        event_id=5,
        name="Gameweek 5",
        deadline=datetime(2024, 9, 12, 16, 30, tzinfo=timezone.utc),
    )
    notifier.send(gameweek, timedelta(hours=2))

    assert opener.last_request is not None
    assert opener.last_request.full_url == "https://api.pushover.net/1/messages.json"
    sent_payload = opener.last_request.data.decode()
    assert "token=token" in sent_payload
    assert "user=user" in sent_payload
    assert "Gameweek+5" in sent_payload
    assert "FPL+deadline+in+2+hours" in sent_payload
