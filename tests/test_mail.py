"""m1 (email-calendar): email accounts (encrypted creds) + IMAP sync (fake
fetcher, no real mailbox) + inbox list."""

from datetime import datetime, timezone

import helm.mail.routes as mail_routes
from fastapi.testclient import TestClient

from helm.app import create_app
from helm.db import Database
from helm.mail.imap import FetchedEmail
from helm.mail.service import AccountService, EmailService


def _client(config) -> TestClient:
    return TestClient(create_app(config))


def test_account_crud_hides_password(config):
    c = _client(config)
    assert c.get("/api/mail/accounts").json()["accounts"] == []

    created = c.post("/api/mail/accounts", json={
        "name": "Personal", "email_addr": "me@x.com", "imap_host": "imap.x.com",
        "username": "me@x.com", "password": "hunter2-SECRET",
    })
    assert created.status_code == 200
    assert "hunter2-SECRET" not in created.text  # never echoed
    body = created.json()
    assert body["has_password"] is True and "password" not in body
    assert body["imap_port"] == 993

    assert "hunter2-SECRET" not in c.get("/api/mail/accounts").text
    aid = body["id"]
    assert c.delete(f"/api/mail/accounts/{aid}").status_code == 200
    assert c.delete(f"/api/mail/accounts/{aid}").status_code == 404


def test_password_encrypted_at_rest(config):
    from helm.crypto import SecretBox

    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    box = SecretBox.from_data_dir(config.data_dir)
    with db.session_scope() as s:
        acc = AccountService(s, box).create(
            name="P", email_addr="me@x.com", imap_host="imap.x.com",
            username="me@x.com", password="topsecret",
        )
        aid = acc.id
        assert "topsecret" not in acc.password_enc  # ciphertext
    with db.session_scope() as s:
        assert AccountService(s, box).password(aid) == "topsecret"  # round-trips


class _FakeFetcher:
    def __init__(self, emails):
        self.emails = emails
        self.creds = None

    def fetch(self, account, password, limit=50):
        self.creds = (account.username, password)
        return self.emails


def _db(config) -> Database:
    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    return db


def test_sync_upserts_by_uid(config):
    from helm.crypto import SecretBox

    db = _db(config)
    box = SecretBox.from_data_dir(config.data_dir)
    with db.session_scope() as s:
        acc = AccountService(s, box).create(
            name="P", email_addr="me@x.com", imap_host="imap.x.com",
            username="me@x.com", password="pw",
        )
        aid = acc.id

    emails = [
        FetchedEmail(uid="1", from_addr="a@x.com", subject="Hi", body="hello there", unread=True,
                     date=datetime(2026, 6, 27, tzinfo=timezone.utc)),
        FetchedEmail(uid="2", from_addr="b@x.com", subject="Invoice", body="pay me"),
    ]
    fetcher = _FakeFetcher(emails)
    with db.session_scope() as s:
        acc = AccountService(s, box).get(aid)
        new = EmailService(s).sync(acc, "pw", fetcher)
        assert new == 2
        assert fetcher.creds == ("me@x.com", "pw")  # decrypted password passed
    # re-sync: same uids → no duplicates
    with db.session_scope() as s:
        acc = AccountService(s, box).get(aid)
        assert EmailService(s).sync(acc, "pw", _FakeFetcher(emails)) == 0
        assert len(EmailService(s).list(account_id=aid)) == 2


def test_inbox_list_and_get_and_sync_route(config, monkeypatch):
    emails = [FetchedEmail(uid="9", from_addr="x@y.com", subject="Urgent", body="please reply")]
    monkeypatch.setattr(mail_routes, "default_fetcher", _FakeFetcher(emails))
    c = _client(config)
    aid = c.post("/api/mail/accounts", json={
        "name": "P", "email_addr": "me@x.com", "imap_host": "imap.x.com",
        "username": "me@x.com", "password": "pw",
    }).json()["id"]

    assert c.post(f"/api/mail/accounts/{aid}/sync").json()["new"] == 1
    assert c.post("/api/mail/accounts/999/sync").status_code == 404

    listed = c.get("/api/mail/emails", params={"account_id": aid}).json()["emails"]
    assert len(listed) == 1 and listed[0]["subject"] == "Urgent"
    eid = listed[0]["id"]
    full = c.get(f"/api/mail/emails/{eid}").json()
    assert full["body"] == "please reply"
    assert c.get("/api/mail/emails/999").status_code == 404

    # unread filter
    assert len(c.get("/api/mail/emails", params={"unread_only": True}).json()["emails"]) == 1
