"""CalDAV client abstraction for bidirectional sync (intent#2).

The sync logic depends only on the ``CalDavClient`` Protocol, so it's
headless-testable with a fake (no server). ``RealCalDavClient`` wraps the
``caldav`` library — real network, exercised only against a live server (a
[needs-human] verification with the user's own CalDAV server).
"""

from __future__ import annotations

from typing import Protocol


class CalDavClient(Protocol):
    def list_events(self) -> list[str]:
        """Return each remote event as raw iCalendar (.ics) text."""
        ...

    def create_event(self, ics: str) -> None:
        """Push a local event (iCalendar text) to the server."""
        ...


class RealCalDavClient:  # pragma: no cover - real network, verified manually
    """Wraps the ``caldav`` lib. Connects lazily on first use; uses the first
    calendar in the principal (MVP — a calendar picker is a later refinement)."""

    def __init__(self, url: str, username: str, password: str) -> None:
        self.url = url
        self.username = username
        self.password = password
        self._calendar = None

    def _cal(self):
        if self._calendar is None:
            import caldav

            client = caldav.DAVClient(
                url=self.url, username=self.username, password=self.password
            )
            calendars = client.principal().calendars()
            if not calendars:
                raise RuntimeError("CalDAV account has no calendars")
            self._calendar = calendars[0]
        return self._calendar

    def list_events(self) -> list[str]:
        return [str(e.data) for e in self._cal().events()]

    def create_event(self, ics: str) -> None:
        self._cal().save_event(ics)
