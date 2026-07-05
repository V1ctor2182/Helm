"""Shared AI plumbing: pick the global provider + run a one-shot completion.

Every non-chat AI feature (速记 enrichment / ask 问大脑 / journal summary…)
funnels through here so the user controls ONE knob: settings key
``ai.provider_id`` (Settings → AI). Unset/invalid → first configured provider.
"""

from __future__ import annotations

import json
from pathlib import Path

from sqlalchemy.orm import Session

from helm.chat import adapters, claudecli
from helm.chat.models import Provider
from helm.chat.service import ProviderService
from helm.crypto import SecretBox
from helm.settings import SettingsService

AI_PROVIDER_KEY = "ai.provider_id"


def pick_provider(session: Session, box: SecretBox) -> Provider | None:
    """The provider all AI features use: settings override, else the first."""
    svc = ProviderService(session, box)
    providers = svc.list()
    if not providers:
        return None
    wanted = SettingsService(session).get(AI_PROVIDER_KEY)
    if wanted:
        for p in providers:
            if str(p.id) == wanted:
                return p
    return providers[0]


async def llm_once(
    session: Session,
    box: SecretBox,
    provider: Provider,
    *,
    system: str,
    user: str,
    cwd: Path | None = None,
) -> str:
    """One-shot completion on the given provider (stream folded to a string)."""
    svc = ProviderService(session, box)
    models = json.loads(provider.models_json or "[]")
    default_model = models[0] if models else ""
    messages = [{"role": "user", "content": user}]
    if provider.type == "claude-cli":
        # base_url 存 claude 二进制路径;历史数据可能是空/"None" → 现场探测兜底。
        binary = provider.base_url
        if not binary or binary == "None":
            binary = claudecli.detect_claude() or binary
        stream = claudecli.chat_stream(
            binary=binary, model=default_model, messages=messages,
            system=system, cwd=cwd)
    else:
        key = svc.api_key(provider.id)
        stream = adapters.chat_stream(
            provider_type=provider.type, base_url=provider.base_url,
            model=default_model, messages=messages, system=system, api_key=key)
    chunks: list[str] = []
    async for chunk in stream:
        chunks.append(chunk)
    return "".join(chunks).strip()
