"""m1 (chat): provider management — templates, CRUD, encrypted keys never
exposed plaintext."""

from fastapi.testclient import TestClient
from sqlalchemy import select

from helm.app import create_app
from helm.chat.models import Provider


def test_provider_templates(config):
    c = TestClient(create_app(config))
    templates = c.get("/api/providers/templates").json()["templates"]
    types = {t["type"] for t in templates}
    assert {"anthropic", "ollama", "openai", "openrouter", "openai-compat"} <= types
    claude = next(t for t in templates if t["type"] == "anthropic")
    assert claude.get("default") is True


def test_provider_crud_hides_key(config):
    c = TestClient(create_app(config))
    assert c.get("/api/providers").json()["providers"] == []

    created = c.post(
        "/api/providers",
        json={
            "type": "anthropic",
            "name": "Claude",
            "base_url": "https://api.anthropic.com",
            "api_key": "sk-ant-SECRET",
            "models": ["claude-opus-4-8"],
        },
    )
    assert created.status_code == 200
    body = created.text
    assert "sk-ant-SECRET" not in body  # key never returned
    pj = created.json()
    assert pj["has_key"] is True
    assert pj["models"] == ["claude-opus-4-8"]

    listed = c.get("/api/providers").json()["providers"]
    assert len(listed) == 1
    assert "sk-ant-SECRET" not in c.get("/api/providers").text


def test_provider_key_encrypted_in_db(config):
    app = create_app(config)
    c = TestClient(app)
    c.post(
        "/api/providers",
        json={"type": "openai", "name": "O", "api_key": "sk-PLAIN", "base_url": "u"},
    )
    with app.state.db.session_scope() as s:
        row = s.execute(select(Provider)).scalars().one()
    assert row.api_key_enc is not None
    assert row.api_key_enc.startswith("enc:")
    assert "sk-PLAIN" not in row.api_key_enc


def test_keyless_provider_and_delete(config):
    c = TestClient(create_app(config))
    pj = c.post(
        "/api/providers", json={"type": "ollama", "name": "Ollama", "base_url": "u"}
    ).json()
    assert pj["has_key"] is False
    assert c.delete(f"/api/providers/{pj['id']}").status_code == 204
    assert c.delete(f"/api/providers/{pj['id']}").status_code == 404


# ---- m2: provider adapters --------------------------------------------------

import httpx
import pytest

from helm.chat import adapters


def test_sse_delta_extractors():
    assert adapters.anthropic_text(
        {"type": "content_block_delta", "delta": {"type": "text_delta", "text": "hi"}}
    ) == "hi"
    assert adapters.anthropic_text({"type": "message_start"}) is None
    assert adapters.openai_text({"choices": [{"delta": {"content": "yo"}}]}) == "yo"
    assert adapters.openai_text({"choices": [{"delta": {}}]}) is None


def _stream_transport(sse_body: str, expect_path: str) -> httpx.MockTransport:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == expect_path
        return httpx.Response(200, text=sse_body)

    return httpx.MockTransport(handler)


@pytest.mark.anyio
async def test_anthropic_chat_stream():
    sse = (
        'data: {"type":"message_start"}\n\n'
        'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Hel"}}\n\n'
        'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"lo"}}\n\n'
        'data: {"type":"message_stop"}\n\n'
    )
    transport = _stream_transport(sse, "/v1/messages")
    async with httpx.AsyncClient(transport=transport) as client:
        chunks = [
            c
            async for c in adapters.chat_stream(
                provider_type="anthropic",
                base_url="https://api.anthropic.com",
                model="claude-opus-4-8",
                messages=[{"role": "user", "content": "hi"}],
                system="be brief",
                api_key="sk-ant",
                client=client,
            )
        ]
    assert "".join(chunks) == "Hello"


@pytest.mark.anyio
async def test_openai_chat_stream():
    sse = (
        'data: {"choices":[{"delta":{"content":"foo"}}]}\n\n'
        'data: {"choices":[{"delta":{"content":"bar"}}]}\n\n'
        "data: [DONE]\n\n"
    )
    transport = _stream_transport(sse, "/v1/chat/completions")
    async with httpx.AsyncClient(transport=transport) as client:
        chunks = [
            c
            async for c in adapters.chat_stream(
                provider_type="openai",
                base_url="https://api.openai.com/v1",
                model="gpt-4o",
                messages=[{"role": "user", "content": "hi"}],
                system=None,
                api_key="sk",
                client=client,
            )
        ]
    assert "".join(chunks) == "foobar"


@pytest.mark.anyio
async def test_ping_lists_models():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"data": [{"id": "m1"}, {"id": "m2"}]})

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        models = await adapters.ping(
            provider_type="openai",
            base_url="https://api.openai.com/v1",
            api_key="sk",
            client=client,
        )
    assert models == ["m1", "m2"]


def test_test_endpoint_404(config):
    c = TestClient(create_app(config))
    assert c.post("/api/providers/999/test").status_code == 404


def test_test_endpoint_pings(config, monkeypatch):
    async def fake_ping(**kwargs):
        return ["model-a"]

    monkeypatch.setattr(adapters, "ping", fake_ping)
    c = TestClient(create_app(config))
    pj = c.post("/api/providers", json={"type": "ollama", "name": "O", "base_url": "u"}).json()
    body = c.post(f"/api/providers/{pj['id']}/test").json()
    assert body["ok"] is True
    assert body["models"] == ["model-a"]


def test_test_endpoint_reports_error(config, monkeypatch):
    async def boom(**kwargs):
        raise httpx.ConnectError("refused")

    monkeypatch.setattr(adapters, "ping", boom)
    c = TestClient(create_app(config))
    pj = c.post("/api/providers", json={"type": "ollama", "name": "O", "base_url": "u"}).json()
    body = c.post(f"/api/providers/{pj['id']}/test").json()
    assert body["ok"] is False
    assert "error" in body


# ---- m3: sessions + streaming chat -----------------------------------------

import asyncio
import json as _json


def _make_provider(c) -> int:
    return c.post("/api/providers", json={"type": "ollama", "name": "O", "base_url": "u"}).json()["id"]


def test_session_crud(config):
    c = TestClient(create_app(config))
    pid = _make_provider(c)
    assert c.post("/api/sessions", json={"provider_id": 999, "model": "m"}).status_code == 404

    sj = c.post(
        "/api/sessions",
        json={"provider_id": pid, "model": "m", "system_prompt": "sys", "title": "T"},
    ).json()
    assert sj["model"] == "m" and sj["system_prompt"] == "sys"

    assert len(c.get("/api/sessions").json()["sessions"]) == 1
    got = c.get(f"/api/sessions/{sj['id']}").json()
    assert got["session"]["title"] == "T"
    assert got["messages"] == []
    assert c.get("/api/sessions/999").status_code == 404


def test_session_delete_removes_messages(config, monkeypatch):
    async def fake_stream(**kwargs):
        yield "ok"

    monkeypatch.setattr(adapters, "chat_stream", fake_stream)
    c = TestClient(create_app(config))
    pid = _make_provider(c)
    sid = c.post("/api/sessions", json={"provider_id": pid, "model": "m"}).json()["id"]
    # persist a user+assistant turn so the delete has FK children to clear
    with c.websocket_connect(f"/api/chat/ws?session_id={sid}") as ws:
        ws.send_text(_json.dumps({"type": "message", "content": "hi"}))
        for _ in range(20):
            if _json.loads(ws.receive_text())["type"] in ("done", "stopped", "error"):
                break
    assert len(c.get(f"/api/sessions/{sid}").json()["messages"]) == 2
    assert c.delete("/api/sessions/999").status_code == 404
    # a provider with sessions refuses deletion (409, not FK 500)
    assert c.delete(f"/api/providers/{pid}").status_code == 409
    assert c.delete(f"/api/sessions/{sid}").status_code == 204
    assert c.get("/api/sessions").json()["sessions"] == []
    assert c.get(f"/api/sessions/{sid}").status_code == 404
    # with its sessions gone the provider deletes cleanly
    assert c.delete(f"/api/providers/{pid}").status_code == 204


def test_chat_ws_streams_persists_restores(config, monkeypatch):
    async def fake_stream(**kwargs):
        for t in ["Hel", "lo"]:
            yield t

    monkeypatch.setattr(adapters, "chat_stream", fake_stream)
    app = create_app(config)
    c = TestClient(app)
    pid = _make_provider(c)
    sid = c.post("/api/sessions", json={"provider_id": pid, "model": "m"}).json()["id"]

    with c.websocket_connect(f"/api/chat/ws?session_id={sid}") as ws:
        ws.send_text(_json.dumps({"type": "message", "content": "hi"}))
        deltas = []
        for _ in range(20):
            m = _json.loads(ws.receive_text())
            if m["type"] == "delta":
                deltas.append(m["text"])
            elif m["type"] in ("done", "stopped", "error"):
                assert m["type"] == "done"
                break
        assert "".join(deltas) == "Hello"

    # restore
    msgs = c.get(f"/api/sessions/{sid}").json()["messages"]
    pairs = [(m["role"], m["content"]) for m in msgs]
    assert pairs == [("user", "hi"), ("assistant", "Hello")]


def test_chat_ws_unknown_session_closes(config):
    c = TestClient(create_app(config))
    import pytest as _pytest
    from starlette.websockets import WebSocketDisconnect as _WSD

    with _pytest.raises(_WSD):
        with c.websocket_connect("/api/chat/ws?session_id=999") as ws:
            ws.receive_text()


def test_chat_ws_stop(config, monkeypatch):
    async def slow_stream(**kwargs):
        for t in ["a", "b", "c", "d", "e"]:
            await asyncio.sleep(0)
            yield t

    monkeypatch.setattr(adapters, "chat_stream", slow_stream)
    app = create_app(config)
    c = TestClient(app)
    pid = _make_provider(c)
    sid = c.post("/api/sessions", json={"provider_id": pid, "model": "m"}).json()["id"]

    with c.websocket_connect(f"/api/chat/ws?session_id={sid}") as ws:
        ws.send_text(_json.dumps({"type": "message", "content": "go"}))
        ws.send_text(_json.dumps({"type": "stop"}))
        term = None
        for _ in range(50):
            m = _json.loads(ws.receive_text())
            if m["type"] in ("done", "stopped", "error"):
                term = m["type"]
                break
        assert term in ("done", "stopped")  # best-effort stop; either is acceptable

    # an assistant turn was persisted (partial or full)
    msgs = c.get(f"/api/sessions/{sid}").json()["messages"]
    assert any(m["role"] == "assistant" for m in msgs)
