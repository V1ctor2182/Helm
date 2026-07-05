"""Chat REST. m1: provider management + built-in templates. Streaming chat
(m3) is added later."""

from __future__ import annotations

import asyncio
import contextlib
import json

import httpx
from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    WebSocket,
    WebSocketDisconnect,    Request,
)
from pydantic import BaseModel
from sqlalchemy.orm import Session

from helm.app import db_session, get_secret_box
from helm.chat import adapters, claudecli
from helm.chat import models  # noqa: F401  (register models on Base.metadata)
from helm.chat.models import ChatSession, Provider
from helm.chat.service import PROVIDER_TEMPLATES, ProviderService, provider_public
from helm.chat.sessions import (
    ChatService,
    message_public,
    session_public,
)
from helm.crypto import DecryptionError, SecretBox

router = APIRouter(prefix="/api", tags=["chat"])


class ProviderBody(BaseModel):
    type: str
    name: str
    base_url: str = ""
    api_key: str | None = None
    models: list[str] | None = None


@router.get("/providers/templates")
def provider_templates() -> dict:
    return {"templates": PROVIDER_TEMPLATES}


@router.get("/providers")
def list_providers(
    session: Session = Depends(db_session),
    box: SecretBox = Depends(get_secret_box),
) -> dict:
    providers = ProviderService(session, box).list()
    return {"providers": [provider_public(p) for p in providers]}


class AskBody(BaseModel):
    q: str


@router.post("/ask")
async def ask_brain(
    body: AskBody, request: Request,
    session: Session = Depends(db_session), box: SecretBox = Depends(get_secret_box),
) -> dict:
    """一句话问大脑(notch 速记 ask 模式):走全局 AI provider(settings ai.provider_id)。"""
    from helm.ai import llm_once, pick_provider

    q = body.q.strip()
    if not q:
        raise HTTPException(status_code=422, detail="q 不能为空")
    provider = pick_provider(session, box)
    if provider is None:
        raise HTTPException(status_code=409, detail="没有可用的模型 provider — 先在 Chat 里配置一个")
    try:
        answer = await llm_once(
            session, box, provider,
            system="用中文简洁回答,直接给答案,不用客套。",
            user=q, cwd=request.app.state.config.data_dir)
    except Exception as exc:  # 转成人话,别把栈炸给刘海
        raise HTTPException(status_code=502, detail=f"大脑没回上来:{exc}") from None
    if not answer:
        raise HTTPException(status_code=502, detail="大脑回了空——检查 provider")
    return {"answer": answer, "provider": provider.name}


@router.post("/providers/claude-cli-setup")
def setup_claude_cli(
    session: Session = Depends(db_session), box: SecretBox = Depends(get_secret_box)
) -> dict:
    """一键接入本机 Claude Code 订阅:探测 claude 二进制,自动建/更新 provider。"""
    binary = claudecli.detect_claude()
    if not binary:
        raise HTTPException(
            status_code=404,
            detail="没找到 claude——先安装 Claude Code 并登录(npm i -g @anthropic-ai/claude-code)",
        )
    svc = ProviderService(session, box)
    existing = next((p for p in svc.list() if p.type == "claude-cli"), None)
    if existing is not None:
        existing.base_url = binary
        session.flush()
        return {"provider": provider_public(existing), "binary": binary, "created": False}
    p = svc.create(
        type="claude-cli", name="Claude Code(订阅)", base_url=binary,
        api_key=None, models=["sonnet", "opus", "haiku"],
    )
    return {"provider": provider_public(p), "binary": binary, "created": True}


@router.post("/providers")
def create_provider(
    body: ProviderBody,
    session: Session = Depends(db_session),
    box: SecretBox = Depends(get_secret_box),
) -> dict:
    svc = ProviderService(session, box)
    provider = svc.create(
        type=body.type,
        name=body.name,
        base_url=body.base_url,
        api_key=body.api_key,
        models=body.models,
    )
    return provider_public(provider)


@router.post("/providers/{provider_id}/test")
async def test_provider(
    provider_id: int,
    session: Session = Depends(db_session),
    box: SecretBox = Depends(get_secret_box),
) -> dict:
    """Ping a provider for connectivity + model discovery."""
    svc = ProviderService(session, box)
    provider = session.get(Provider, provider_id)
    if provider is None:
        raise HTTPException(status_code=404, detail="provider not found")
    if provider.type == "claude-cli":
        from pathlib import Path

        ok = bool(provider.base_url) and Path(provider.base_url).exists()
        return {"ok": ok, "models": ["sonnet", "opus", "haiku"]} if ok else {
            "ok": False, "error": f"找不到 claude 可执行文件:{provider.base_url}"}
    try:
        key = svc.api_key(provider_id)  # may raise DecryptionError on a lost key
        available = await adapters.ping(
            provider_type=provider.type, base_url=provider.base_url, api_key=key
        )
        return {"ok": True, "models": available}
    except (httpx.HTTPError, DecryptionError) as exc:
        return {"ok": False, "error": str(exc)}


@router.delete("/providers/{provider_id}", status_code=204)
def delete_provider(
    provider_id: int,
    session: Session = Depends(db_session),
    box: SecretBox = Depends(get_secret_box),
) -> None:
    from sqlalchemy import select

    # 有会话引用时 FK 会炸 500 —— 显式挡成 409,让前端能给出可行动的提示。
    if session.scalars(
        select(ChatSession.id).where(ChatSession.provider_id == provider_id).limit(1)
    ).first() is not None:
        raise HTTPException(status_code=409, detail="provider 有会话引用,先删除其会话")
    if not ProviderService(session, box).delete(provider_id):
        raise HTTPException(status_code=404, detail="provider not found")


# ---- m3: chat sessions + streaming ----------------------------------------


class SessionBody(BaseModel):
    provider_id: int
    model: str
    system_prompt: str | None = None
    title: str | None = None
    project_path: str | None = None


@router.post("/sessions")
def create_session(body: SessionBody, session: Session = Depends(db_session)) -> dict:
    if session.get(Provider, body.provider_id) is None:
        raise HTTPException(status_code=404, detail="provider not found")
    s = ChatService(session).create_session(
        provider_id=body.provider_id,
        model=body.model,
        system_prompt=body.system_prompt,
        title=body.title,
        project_path=body.project_path,
    )
    return session_public(s)


@router.get("/sessions")
def list_sessions(session: Session = Depends(db_session)) -> dict:
    return {"sessions": [session_public(s) for s in ChatService(session).list_sessions()]}


@router.delete("/sessions/{session_id}", status_code=204)
def delete_session(session_id: int, session: Session = Depends(db_session)) -> None:
    if not ChatService(session).delete_session(session_id):
        raise HTTPException(status_code=404, detail="session not found")


@router.get("/sessions/{session_id}")
def get_session(session_id: int, session: Session = Depends(db_session)) -> dict:
    svc = ChatService(session)
    s = svc.get_session(session_id)
    if s is None:
        raise HTTPException(status_code=404, detail="session not found")
    return {
        "session": session_public(s),
        "messages": [message_public(m) for m in svc.messages(session_id)],
    }


@router.websocket("/chat/ws")
async def chat_ws(ws: WebSocket, session_id: int) -> None:
    """Streaming chat. Protocol — client: {type:'message',content} /
    {type:'stop'}; server: {type:'delta',text} / {type:'done'} /
    {type:'stopped'} / {type:'error',error}. User+assistant turns persist so the
    session restores (constraint e9ddc41a)."""
    await ws.accept()
    db = ws.app.state.db
    box = ws.app.state.secret_box
    config = ws.app.state.config

    # Snapshot the session + provider (rows detach after the scope closes).
    with db.session_scope() as s:
        sess = s.get(ChatSession, session_id)
        if sess is None:
            await ws.close(code=1008)
            return
        provider = s.get(Provider, sess.provider_id)
        if provider is None:
            await ws.close(code=1008)
            return
        model, system = sess.model, sess.system_prompt
        ptype, base_url, key_enc = provider.type, provider.base_url, provider.api_key_enc

    try:
        api_key = box.decrypt(key_enc) if key_enc else None
    except DecryptionError:
        await ws.send_text(json.dumps({"type": "error", "error": "cannot decrypt provider key"}))
        await ws.close()
        return

    stop_event: asyncio.Event | None = None
    task: asyncio.Task | None = None

    async def run_turn(user_content: str) -> None:
        # Persist the user turn, then stream the assistant reply.
        with db.session_scope() as s:
            ChatService(s).add_message(session_id, "user", user_content)
        with db.session_scope() as s:
            history = [
                {"role": m.role, "content": m.content}
                for m in ChatService(s).messages(session_id)
            ]
        acc: list[str] = []
        error: str | None = None
        try:
            stream = (
                claudecli.chat_stream(
                    binary=base_url,  # claude-cli:base_url 存的是探测到的绝对路径
                    model=model,
                    messages=history,
                    system=system,
                    cwd=config.data_dir,
                )
                if ptype == "claude-cli"
                else adapters.chat_stream(
                    provider_type=ptype,
                    base_url=base_url,
                    model=model,
                    messages=history,
                    system=system,
                    api_key=api_key,
                )
            )
            async for chunk in stream:
                if stop_event and stop_event.is_set():
                    break
                acc.append(chunk)
                await ws.send_text(json.dumps({"type": "delta", "text": chunk}))
        except httpx.HTTPError as exc:
            error = str(exc)
        except (WebSocketDisconnect, RuntimeError):
            # Client vanished mid-stream: persist what we have, stop quietly.
            with db.session_scope() as s:
                ChatService(s).add_message(session_id, "assistant", "".join(acc))
            return

        # Persist whatever we got (full or partial) so restore is faithful.
        with db.session_scope() as s:
            ChatService(s).add_message(session_id, "assistant", "".join(acc))
        stopped = bool(stop_event and stop_event.is_set())
        final = (
            {"type": "error", "error": error}
            if error
            else {"type": "stopped" if stopped else "done"}
        )
        try:
            await ws.send_text(json.dumps(final))
        except (WebSocketDisconnect, RuntimeError):
            pass  # peer already gone; the turn is already persisted

    try:
        while True:
            msg = json.loads(await ws.receive_text())
            if msg.get("type") == "message":
                # One turn at a time — overlapping turns would interleave sends
                # on the single socket and orphan the prior task.
                if task and not task.done():
                    await ws.send_text(
                        json.dumps({"type": "error", "error": "a turn is already in progress"})
                    )
                    continue
                stop_event = asyncio.Event()
                task = asyncio.create_task(run_turn(msg.get("content", "")))
            elif msg.get("type") == "stop":
                if stop_event:
                    stop_event.set()  # best-effort: takes effect at the next token
    except WebSocketDisconnect:
        pass
    finally:
        if stop_event:
            stop_event.set()
        if task and not task.done():
            task.cancel()
            with contextlib.suppress(asyncio.CancelledError, Exception):
                await task  # join so the cancellation/cleanup completes
