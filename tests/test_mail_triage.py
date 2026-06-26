"""m2 (email-calendar): AI email triage (fake LLM — no real LLM call)."""

import json

import helm.mail.routes as mail_routes
from fastapi.testclient import TestClient

from helm.app import create_app
from helm.chat.service import ProviderService
from helm.crypto import SecretBox
from helm.db import Database
from helm.mail.models import Email, EmailAccount
from helm.mail.service import EmailService
from helm.mail.triage import triage_email


class _LLM:
    def __init__(self, raw):
        self.raw = raw

    def complete(self, prompt, system=None):
        assert "发件人" in prompt and "只输出 JSON" in prompt
        return self.raw


def test_triage_normalizes_good_json():
    e = Email(from_addr="boss@x.com", subject="urgent", body="reply asap")
    out = triage_email(e, _LLM(json.dumps({
        "urgency": "HIGH", "is_spam": False, "summary": "老板催回复",
        "labels": ["工作", "紧急", "x", "y"], "draft": "好的,马上处理。",
    })))
    assert out["urgency"] == "high"  # lowercased
    assert out["labels"] == ["工作", "紧急", "x"]  # capped at 3
    assert out["draft"] == "好的,马上处理。"


def test_triage_defaults_on_junk():
    e = Email(from_addr="x", subject="y", body="z")
    out = triage_email(e, _LLM("not json at all"))
    assert out == {"urgency": "low", "is_spam": False, "summary": "", "labels": [], "draft": ""}


def _db(config) -> Database:
    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    return db


def test_service_triage_persists(config):
    db = _db(config)
    with db.session_scope() as s:
        acc = EmailAccount(name="a", email_addr="m@x.com", imap_host="h", username="u", password_enc="x")
        s.add(acc)
        s.flush()
        e = Email(account_id=acc.id, uid="1", subject="bill", body="pay $9")
        s.add(e)
        s.flush()
        eid = e.id
    with db.session_scope() as s:
        out = EmailService(s).triage(eid, _LLM(json.dumps({
            "urgency": "medium", "is_spam": False, "summary": "账单", "labels": ["账单"], "draft": "",
        })))
        assert out["summary"] == "账单"
    with db.session_scope() as s:
        e = EmailService(s).get(eid)
        assert json.loads(e.triage_json)["urgency"] == "medium"
        assert json.loads(e.labels_json) == ["账单"]  # labels promoted for filtering


class _FakeChatLLM:
    def __init__(self, *a, **k):
        pass

    def complete(self, prompt, system=None):
        return json.dumps({"urgency": "high", "is_spam": False, "summary": "面试邀约", "labels": ["工作"], "draft": "谢谢,我有空。"})


def test_triage_route(config, monkeypatch):
    monkeypatch.setattr(mail_routes, "ChatLLM", _FakeChatLLM)
    c = TestClient(create_app(config))
    db = Database.from_data_dir(config.data_dir)
    box = SecretBox.from_data_dir(config.data_dir)
    with db.session_scope() as s:
        pid = ProviderService(s, box).create(type="openai", name="O", base_url="u", api_key="k", models=["m"]).id
        acc = EmailAccount(name="a", email_addr="m@x.com", imap_host="h", username="u", password_enc="x")
        s.add(acc)
        s.flush()
        e = Email(account_id=acc.id, uid="1", subject="interview", body="are you free?")
        s.add(e)
        s.flush()
        eid = e.id

    res = c.post(f"/api/mail/emails/{eid}/triage", json={"provider_id": pid, "model": "m"})
    assert res.status_code == 200
    assert res.json()["urgency"] == "high" and "面试" in res.json()["summary"]
    # email now carries triage in the list view
    listed = c.get("/api/mail/emails").json()["emails"]
    assert listed[0]["triage"]["draft"].startswith("谢谢")
    # 404s
    assert c.post("/api/mail/emails/999/triage", json={"provider_id": pid, "model": "m"}).status_code == 404
    assert c.post(f"/api/mail/emails/{eid}/triage", json={"provider_id": 999, "model": "m"}).status_code == 404
