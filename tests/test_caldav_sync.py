"""CalDAV bidirectional sync (intent#2) — fake client, no real server."""

from datetime import datetime, timezone

import helm.calendar.routes as cal_routes
from fastapi.testclient import TestClient

from helm.app import create_app
from helm.calendar.ics import events_to_ics
from helm.calendar.service import CalDavAccountService, EventService
from helm.crypto import SecretBox
from helm.db import Database

UTC = timezone.utc

REMOTE_ICS = """BEGIN:VCALENDAR
BEGIN:VEVENT
UID:remote-1@srv
SUMMARY:Remote meeting
DTSTART:20260629T140000Z
END:VEVENT
END:VCALENDAR
"""


class _FakeCalDav:
    def __init__(self, remote_ics):
        self.remote = remote_ics
        self.created: list[str] = []

    def list_events(self):
        return self.remote

    def create_event(self, ics):
        self.created.append(ics)


def _db(config) -> Database:
    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    return db


def test_sync_pulls_remote_and_pushes_local(config):
    db = _db(config)
    with db.session_scope() as s:
        svc = EventService(s)
        # a local-only event (should be pushed)
        svc.create(summary="Local standup", start=datetime(2026, 6, 28, 9, tzinfo=UTC), source="local")
        client = _FakeCalDav([REMOTE_ICS])
        result = svc.sync_caldav(client)
        assert result == {"pulled_new": 1, "pushed": 1}
        # remote event pulled in
        summaries = {e.summary for e in svc.list()}
        assert "Remote meeting" in summaries and "Local standup" in summaries
        # local event was pushed (and re-tagged caldav)
        assert len(client.created) == 1 and "Local standup" in client.created[0]
        local = next(e for e in svc.list() if e.summary == "Local standup")
        assert local.source == "caldav"


def test_sync_dedups_by_uid(config):
    db = _db(config)
    with db.session_scope() as s:
        svc = EventService(s)
        svc.sync_caldav(_FakeCalDav([REMOTE_ICS]))  # pulls remote-1
    with db.session_scope() as s:
        svc = EventService(s)
        r = svc.sync_caldav(_FakeCalDav([REMOTE_ICS]))  # same uid → no dup
        assert r["pulled_new"] == 0
        assert len([e for e in svc.list() if e.uid == "remote-1@srv"]) == 1


def test_caldav_sync_route(config, monkeypatch):
    fake = _FakeCalDav([REMOTE_ICS])
    monkeypatch.setattr(cal_routes, "make_caldav_client", lambda account, password: fake)
    c = TestClient(create_app(config))
    db = Database.from_data_dir(config.data_dir)
    box = SecretBox.from_data_dir(config.data_dir)
    with db.session_scope() as s:
        aid = CalDavAccountService(s, box).create(name="iCloud", url="u", username="me", password="pw").id

    res = c.post(f"/api/calendar/accounts/{aid}/sync")
    assert res.status_code == 200 and res.json()["pulled_new"] == 1
    assert any(e["summary"] == "Remote meeting" for e in c.get("/api/calendar/events").json()["events"])
    assert c.post("/api/calendar/accounts/999/sync").status_code == 404


def test_caldav_sync_route_surfaces_errors(config, monkeypatch):
    def boom(account, password):
        raise RuntimeError("auth failed")

    monkeypatch.setattr(cal_routes, "make_caldav_client", boom)
    c = TestClient(create_app(config))
    db = Database.from_data_dir(config.data_dir)
    box = SecretBox.from_data_dir(config.data_dir)
    with db.session_scope() as s:
        aid = CalDavAccountService(s, box).create(name="x", url="u", username="me", password="pw").id
    assert c.post(f"/api/calendar/accounts/{aid}/sync").status_code == 502
