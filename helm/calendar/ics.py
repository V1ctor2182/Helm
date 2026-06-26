"""Minimal iCalendar (.ics) parse + serialize — no dependency.

Handles the VEVENT fields the MVP needs: UID/SUMMARY/DESCRIPTION/LOCATION +
DTSTART/DTEND (UTC datetimes ``…Z`` or all-day ``VALUE=DATE``). Good enough for
import/export round-trips; a full RFC5545 lib (icalendar) can replace it if rich
recurrence/timezones are needed later."""

from __future__ import annotations

from datetime import date, datetime, timezone

_DT_FMT = "%Y%m%dT%H%M%SZ"
_DATE_FMT = "%Y%m%d"


def _escape(text: str) -> str:
    return (
        (text or "")
        .replace("\\", "\\\\")
        .replace("\n", "\\n")
        .replace(",", "\\,")
        .replace(";", "\\;")
    )


def _unescape(text: str) -> str:
    out, i = [], 0
    while i < len(text):
        c = text[i]
        if c == "\\" and i + 1 < len(text):
            nxt = text[i + 1]
            out.append("\n" if nxt == "n" else nxt)
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def _parse_dt(value: str, is_date: bool) -> tuple[datetime, bool]:
    if is_date or (len(value) == 8 and value.isdigit()):
        d = datetime.strptime(value, _DATE_FMT)
        return d.replace(tzinfo=timezone.utc), True
    val = value.rstrip("Z")
    dt = datetime.strptime(val, "%Y%m%dT%H%M%S")
    return dt.replace(tzinfo=timezone.utc), False


def parse_ics(text: str) -> list[dict]:
    """Parse VEVENTs into dicts (uid/summary/description/location/start/end/all_day)."""
    events: list[dict] = []
    cur: dict | None = None
    for raw in text.splitlines():
        line = raw.strip()
        if line == "BEGIN:VEVENT":
            cur = {"all_day": False}
        elif line == "END:VEVENT":
            if cur is not None and cur.get("start"):
                events.append(cur)
            cur = None
        elif cur is not None and ":" in line:
            name, _, value = line.partition(":")
            key = name.split(";")[0].upper()
            is_date = "VALUE=DATE" in name.upper()
            if key == "SUMMARY":
                cur["summary"] = _unescape(value)
            elif key == "DESCRIPTION":
                cur["description"] = _unescape(value)
            elif key == "LOCATION":
                cur["location"] = _unescape(value)
            elif key == "UID":
                cur["uid"] = value
            elif key == "DTSTART":
                cur["start"], cur["all_day"] = _parse_dt(value, is_date)
            elif key == "DTEND":
                cur["end"], _ = _parse_dt(value, is_date)
    return events


def _fmt_dt(dt: datetime, all_day: bool) -> str:
    if isinstance(dt, date) and not isinstance(dt, datetime):
        return dt.strftime(_DATE_FMT)
    if all_day:
        return dt.strftime(_DATE_FMT)
    return dt.astimezone(timezone.utc).strftime(_DT_FMT)


def event_to_vevent(ev) -> list[str]:
    """``ev`` may be a CalendarEvent or a dict with the same attrs."""

    def g(name, default=""):
        return getattr(ev, name, None) if not isinstance(ev, dict) else ev.get(name, default)

    all_day = bool(g("all_day", False))
    lines = [
        "BEGIN:VEVENT",
        f"UID:{g('uid') or 'helm-event'}",
        f"SUMMARY:{_escape(g('summary'))}",
    ]
    if g("description"):
        lines.append(f"DESCRIPTION:{_escape(g('description'))}")
    if g("location"):
        lines.append(f"LOCATION:{_escape(g('location'))}")
    start = g("start")
    if start:
        prefix = "DTSTART;VALUE=DATE" if all_day else "DTSTART"
        lines.append(f"{prefix}:{_fmt_dt(start, all_day)}")
    end = g("end")
    if end:
        prefix = "DTEND;VALUE=DATE" if all_day else "DTEND"
        lines.append(f"{prefix}:{_fmt_dt(end, all_day)}")
    lines.append("END:VEVENT")
    return lines


def events_to_ics(events) -> str:
    lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Helm//Calendar//EN"]
    for ev in events:
        lines.extend(event_to_vevent(ev))
    lines.append("END:VCALENDAR")
    return "\r\n".join(lines) + "\r\n"
