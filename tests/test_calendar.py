"""m4 (email-calendar): calendar events + .ics import/export + CalDAV account."""

from datetime import datetime, timezone

from fastapi.testclient import TestClient

from helm.app import create_app
from helm.calendar.ics import events_to_ics, parse_ics
from helm.calendar.service import CalDavAccountService, EventService
from helm.crypto import SecretBox
from helm.db import Database

UTC = timezone.utc

SAMPLE_ICS = """BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:evt-1@helm
SUMMARY:Team sync
DESCRIPTION:weekly\\, on zoom
LOCATION:Zoom
DTSTART:20260627T090000Z
DTEND:20260627T093000Z
END:VEVENT
BEGIN:VEVENT
UID:evt-2@helm
SUMMARY:Holiday
DTSTART;VALUE=DATE:20260628
END:VEVENT
END:VCALENDAR
"""


def test_parse_ics():
    events = parse_ics(SAMPLE_ICS)
    assert len(events) == 2
    e0 = events[0]
    assert e0["summary"] == "Team sync"
    assert e0["description"] == "weekly, on zoom"  # unescaped
    assert e0["start"] == datetime(2026, 6, 27, 9, 0, tzinfo=UTC)
    assert e0["all_day"] is False
    assert events[1]["all_day"] is True  # VALUE=DATE


def test_ics_roundtrip():
    events = parse_ics(SAMPLE_ICS)
    out = events_to_ics(events)
    reparsed = parse_ics(out)
    assert [e["summary"] for e in reparsed] == ["Team sync", "Holiday"]
    assert reparsed[0]["start"] == events[0]["start"]
    assert reparsed[1]["all_day"] is True


def _db(config) -> Database:
    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    return db


def test_event_crud_and_range(config):
    db = _db(config)
    with db.session_scope() as s:
        svc = EventService(s)
        svc.create(summary="early", start=datetime(2026, 6, 1, tzinfo=UTC))
        svc.create(summary="mid", start=datetime(2026, 6, 15, tzinfo=UTC))
        svc.create(summary="late", start=datetime(2026, 6, 30, tzinfo=UTC))
        in_range = svc.list(
            start=datetime(2026, 6, 10, tzinfo=UTC), end=datetime(2026, 6, 20, tzinfo=UTC)
        )
        assert [e.summary for e in in_range] == ["mid"]


def test_import_ics_dedups_by_uid(config):
    db = _db(config)
    with db.session_scope() as s:
        assert EventService(s).import_ics(SAMPLE_ICS) == 2
    with db.session_scope() as s:
        assert EventService(s).import_ics(SAMPLE_ICS) == 0  # same uids
        assert len(EventService(s).list()) == 2


def test_caldav_account_encrypted(config):
    db = _db(config)
    box = SecretBox.from_data_dir(config.data_dir)
    with db.session_scope() as s:
        a = CalDavAccountService(s, box).create(
            name="iCloud", url="https://caldav.icloud.com", username="me", password="app-pw"
        )
        aid = a.id
        assert "app-pw" not in a.password_enc
    with db.session_scope() as s:
        assert CalDavAccountService(s, box).password(aid) == "app-pw"


def test_calendar_routes(config):
    c = TestClient(create_app(config))
    assert c.get("/api/calendar/events").json()["events"] == []

    created = c.post("/api/calendar/events", json={"summary": "Demo", "start": "2026-06-27T10:00:00+00:00"})
    assert created.status_code == 200 and created.json()["uid"].startswith("helm-")
    assert c.post("/api/calendar/events", json={"summary": "  ", "start": "2026-06-27T10:00:00+00:00"}).status_code == 422

    imported = c.post("/api/calendar/import", json={"ics": SAMPLE_ICS})
    assert imported.json()["imported"] == 2

    export = c.get("/api/calendar/export").text
    assert "BEGIN:VCALENDAR" in export and "Team sync" in export

    eid = created.json()["id"]
    assert c.delete(f"/api/calendar/events/{eid}").status_code == 200
    assert c.delete(f"/api/calendar/events/{eid}").status_code == 404

    # caldav account (creds encrypted, password never echoed)
    acc = c.post("/api/calendar/accounts", json={"name": "iCloud", "url": "u", "username": "me", "password": "SECRET-pw"})
    assert acc.status_code == 200 and "SECRET-pw" not in acc.text
    assert "SECRET-pw" not in c.get("/api/calendar/accounts").text
