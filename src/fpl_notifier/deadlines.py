"""Utilities for working with Fantasy Premier League deadlines."""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timezone
import logging
from typing import Callable, List, Optional, Sequence
from urllib import request

LOGGER = logging.getLogger(__name__)

API_URL = "https://fantasy.premierleague.com/api/bootstrap-static/"

FetchJson = Callable[[str, int], dict]


@dataclass(frozen=True)
class GameweekDeadline:
    """Represents a Fantasy Premier League gameweek deadline."""

    event_id: int
    name: str
    deadline: datetime

    def __post_init__(self) -> None:
        if self.deadline.tzinfo is None:
            raise ValueError("deadline must be timezone aware")

    def __str__(self) -> str:  # pragma: no cover - trivial representation
        return f"{self.name} (GW {self.event_id}) @ {self.deadline.isoformat()}"


def _coerce_to_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def parse_deadline(deadline_str: str) -> datetime:
    """Parse a deadline string from the FPL API into an aware UTC datetime."""

    # FPL returns strings such as "2024-08-16T18:30:00Z".
    if deadline_str.endswith("Z"):
        deadline_str = deadline_str[:-1] + "+00:00"
    dt = datetime.fromisoformat(deadline_str)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    else:
        dt = dt.astimezone(timezone.utc)
    return dt


def _default_fetch(url: str, timeout: int) -> dict:
    with request.urlopen(url, timeout=timeout) as response:
        return json.load(response)


def fetch_gameweek_deadlines(
    *,
    now: Optional[datetime] = None,
    fetch_json: Optional[FetchJson] = None,
) -> List[GameweekDeadline]:
    """Fetch upcoming gameweek deadlines from the public FPL API."""

    if now is None:
        now = datetime.now(timezone.utc)
    else:
        now = _coerce_to_utc(now)

    fetcher = fetch_json or _default_fetch
    LOGGER.debug("Fetching FPL data from %s", API_URL)
    payload = fetcher(API_URL, 10)
    events: Sequence[dict] = payload.get("events", [])
    deadlines: List[GameweekDeadline] = []
    for event in events:
        try:
            deadline = parse_deadline(event["deadline_time"])
        except (KeyError, TypeError, ValueError) as exc:
            LOGGER.warning("Skipping event with invalid deadline: %s", exc)
            continue
        if deadline <= now:
            # Skip past deadlines, including the current active gameweek.
            continue
        deadlines.append(
            GameweekDeadline(
                event_id=int(event["id"]),
                name=str(event.get("name") or event.get("event", "Gameweek")),
                deadline=deadline,
            )
        )

    deadlines.sort(key=lambda gw: gw.deadline)
    LOGGER.debug("Found %d upcoming deadlines", len(deadlines))
    return deadlines


def get_next_gameweek_deadline(
    *,
    now: Optional[datetime] = None,
    fetch_json: Optional[FetchJson] = None,
) -> Optional[GameweekDeadline]:
    """Return the next upcoming gameweek deadline, if one exists."""

    deadlines = fetch_gameweek_deadlines(now=now, fetch_json=fetch_json)
    if not deadlines:
        return None
    return deadlines[0]
