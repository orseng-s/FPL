"""Notification backends for delivering deadline reminders."""

from __future__ import annotations

from datetime import timedelta
import logging
from typing import Optional
from urllib import error, parse, request

from zoneinfo import ZoneInfo

from .deadlines import GameweekDeadline

LOGGER = logging.getLogger(__name__)

PUSHOVER_API_URL = "https://api.pushover.net/1/messages.json"


def _format_timedelta(delta: timedelta) -> str:
    total_seconds = int(delta.total_seconds())
    if total_seconds < 60:
        return f"{total_seconds} seconds"
    minutes, seconds = divmod(total_seconds, 60)
    hours, minutes = divmod(minutes, 60)
    parts = []
    if hours:
        parts.append(f"{hours} hour{'s' if hours != 1 else ''}")
    if minutes:
        parts.append(f"{minutes} minute{'s' if minutes != 1 else ''}")
    if seconds and not hours:
        parts.append(f"{seconds} second{'s' if seconds != 1 else ''}")
    return " and ".join(parts)


class PushoverNotifier:
    """Send push notifications using the Pushover service."""

    def __init__(
        self,
        token: str,
        user_key: str,
        *,
        opener: Optional[request.OpenerDirector] = None,
        timezone: Optional[ZoneInfo] = None,
        sound: Optional[str] = None,
        device: Optional[str] = None,
        priority: Optional[int] = None,
        timeout: int = 10,
    ) -> None:
        if not token:
            raise ValueError("token is required")
        if not user_key:
            raise ValueError("user_key is required")

        self.token = token
        self.user_key = user_key
        self.opener = opener or request.build_opener()
        self.timezone = timezone or ZoneInfo("UTC")
        self.sound = sound
        self.device = device
        self.priority = priority
        self.timeout = timeout

    def _build_payload(self, gameweek: GameweekDeadline, lead_time: timedelta) -> dict:
        deadline_local = gameweek.deadline.astimezone(self.timezone)
        formatted_lead = _format_timedelta(lead_time)
        title = f"FPL deadline in {formatted_lead}"
        message = (
            f"{gameweek.name} (GW {gameweek.event_id}) deadline at "
            f"{deadline_local.strftime('%Y-%m-%d %H:%M %Z')}"
        )
        payload = {
            "token": self.token,
            "user": self.user_key,
            "title": title,
            "message": message,
        }
        if self.sound:
            payload["sound"] = self.sound
        if self.device:
            payload["device"] = self.device
        if self.priority is not None:
            payload["priority"] = str(self.priority)
        return payload

    def send(self, gameweek: GameweekDeadline, lead_time: timedelta) -> None:
        """Send a push notification for the provided gameweek."""

        payload = self._build_payload(gameweek, lead_time)
        LOGGER.info("Sending push notification for %s", gameweek)
        encoded = parse.urlencode(payload).encode()
        req = request.Request(PUSHOVER_API_URL, data=encoded)
        try:
            with self.opener.open(req, timeout=self.timeout) as response:
                status = response.getcode()
                body = response.read().decode("utf-8", errors="replace")
        except error.HTTPError as exc:
            LOGGER.error("Pushover rejected the request: %s", exc.read().decode("utf-8", errors="replace"))
            raise
        except error.URLError as exc:
            LOGGER.error("Failed to contact Pushover: %s", exc)
            raise
        else:
            LOGGER.debug("Notification accepted (status %s): %s", status, body)
