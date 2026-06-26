"""Schedule math: compute a task's next fire time for the three modes
(decision 894165f7). Pure + tz-aware (UTC); no DB."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from croniter import croniter

KINDS = ("at", "every", "cron")


def _aware(dt: datetime) -> datetime:
    return dt if dt.tzinfo is not None else dt.replace(tzinfo=timezone.utc)


def compute_next_run(kind: str, value: dict, after: datetime) -> datetime | None:
    """Next fire time strictly after ``after``, or None if the task won't fire
    again (a past one-shot 'at', or a malformed schedule)."""
    after = _aware(after)
    if kind == "at":
        raw = value.get("at")
        if not isinstance(raw, str):
            return None
        try:
            dt = _aware(datetime.fromisoformat(raw))
        except ValueError:
            return None
        return dt if dt > after else None
    if kind == "every":
        try:
            seconds = int(value.get("seconds", 0))
        except (TypeError, ValueError):
            return None
        return after + timedelta(seconds=seconds) if seconds > 0 else None
    if kind == "cron":
        expr = value.get("expr")
        if not expr or not croniter.is_valid(expr):
            return None
        return _aware(croniter(expr, after).get_next(datetime))
    return None
