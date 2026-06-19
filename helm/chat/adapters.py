"""Thin provider adapters (raw httpx) — a deliberately provider-neutral layer,
not a single-provider Anthropic app, so we use httpx rather than the anthropic
SDK to keep one uniform streaming interface across providers.

Two backends cover the configured providers:
  - anthropic        → Messages API (x-api-key + anthropic-version)
  - openai-compatible → /chat/completions (Bearer) for openai/openrouter/ollama/compat

We deliberately send only model/system/messages/max_tokens/stream — no
temperature/thinking — so the same call works across model versions (Opus
4.7/4.8 reject sampling params).
"""

from __future__ import annotations

import json
from collections.abc import AsyncIterator

import httpx

ANTHROPIC_VERSION = "2023-06-01"
_DEFAULT_MAX_TOKENS = 4096


def _is_anthropic(provider_type: str) -> bool:
    return provider_type == "anthropic"


# ---- SSE delta extraction (pure, unit-testable) ---------------------------


def anthropic_text(event: dict) -> str | None:
    if event.get("type") == "content_block_delta":
        delta = event.get("delta") or {}
        if delta.get("type") == "text_delta":
            return delta.get("text")
    return None


def openai_text(event: dict) -> str | None:
    try:
        return event["choices"][0]["delta"].get("content")
    except (KeyError, IndexError, TypeError):
        return None


# ---- streaming chat -------------------------------------------------------


async def chat_stream(
    *,
    provider_type: str,
    base_url: str,
    model: str,
    messages: list[dict],
    system: str | None,
    api_key: str | None,
    client: httpx.AsyncClient | None = None,
    max_tokens: int = _DEFAULT_MAX_TOKENS,
) -> AsyncIterator[str]:
    """Yield text chunks for a chat completion. `messages` are
    [{role: 'user'|'assistant', content: str}]. Pass `client` to inject (tests);
    otherwise one is created and closed here."""
    base = base_url.rstrip("/")
    if _is_anthropic(provider_type):
        url = f"{base}/v1/messages"
        headers = {"anthropic-version": ANTHROPIC_VERSION, "content-type": "application/json"}
        if api_key:
            headers["x-api-key"] = api_key
        body: dict = {"model": model, "max_tokens": max_tokens, "messages": messages, "stream": True}
        if system:
            body["system"] = system
        extract = anthropic_text
    else:  # openai-compatible
        url = f"{base}/chat/completions"
        headers = {"content-type": "application/json"}
        if api_key:
            headers["authorization"] = f"Bearer {api_key}"
        msgs = ([{"role": "system", "content": system}] if system else []) + messages
        body = {"model": model, "messages": msgs, "stream": True}
        extract = openai_text

    own = client is None
    if client is None:
        client = httpx.AsyncClient(timeout=60)
    try:
        async with client.stream("POST", url, headers=headers, json=body) as resp:
            resp.raise_for_status()
            async for line in resp.aiter_lines():
                if not line.startswith("data:"):
                    continue
                data = line[len("data:") :].strip()
                if data == "[DONE]" or not data:
                    continue
                try:
                    event = json.loads(data)
                except json.JSONDecodeError:
                    continue
                text = extract(event)
                if text:
                    yield text
    finally:
        if own:
            await client.aclose()


async def ping(
    *,
    provider_type: str,
    base_url: str,
    api_key: str | None,
    client: httpx.AsyncClient | None = None,
) -> list[str]:
    """Connectivity test + model discovery — returns available model ids."""
    base = base_url.rstrip("/")
    if _is_anthropic(provider_type):
        url = f"{base}/v1/models"
        headers = {"anthropic-version": ANTHROPIC_VERSION}
        if api_key:
            headers["x-api-key"] = api_key
    else:
        url = f"{base}/models"
        headers = {}
        if api_key:
            headers["authorization"] = f"Bearer {api_key}"

    own = client is None
    if client is None:
        client = httpx.AsyncClient(timeout=15)
    try:
        resp = await client.get(url, headers=headers)
        resp.raise_for_status()
        data = resp.json()
        return [m["id"] for m in data.get("data", []) if "id" in m]
    finally:
        if own:
            await client.aclose()
