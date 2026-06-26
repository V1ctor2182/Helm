"""LLM provider for research: reuses Helm's configured chat providers
(chat-multimodel) via a sync, non-streaming completion call. Mirrors the URL/
header/body shape of helm.chat.adapters but synchronous (the engine loop is
sync) and non-streaming (research wants the whole answer, not deltas).

httpx client injectable → tests drive it with MockTransport (no real LLM/cost).
"""

from __future__ import annotations

import httpx

ANTHROPIC_VERSION = "2023-06-01"
_MAX_TOKENS = 4096


class ChatLLM:
    def __init__(
        self,
        provider_type: str,
        base_url: str,
        model: str,
        api_key: str | None = None,
        client: httpx.Client | None = None,
    ) -> None:
        self.provider_type = provider_type
        self.base_url = base_url.rstrip("/")
        self.model = model
        self.api_key = api_key
        self._client = client
        self._owned = client is None

    def complete(self, prompt: str, system: str | None = None) -> str:
        client = self._client or httpx.Client(timeout=120.0)
        try:
            if self.provider_type == "anthropic":
                return self._anthropic(client, prompt, system)
            return self._openai(client, prompt, system)
        finally:
            if self._owned:
                client.close()

    def _anthropic(self, client: httpx.Client, prompt: str, system: str | None) -> str:
        headers = {
            "anthropic-version": ANTHROPIC_VERSION,
            "content-type": "application/json",
        }
        if self.api_key:
            headers["x-api-key"] = self.api_key
        body: dict = {
            "model": self.model,
            "max_tokens": _MAX_TOKENS,
            "messages": [{"role": "user", "content": prompt}],
        }
        if system:
            body["system"] = system
        resp = client.post(f"{self.base_url}/v1/messages", json=body, headers=headers)
        resp.raise_for_status()
        data = resp.json()
        blocks = data.get("content") or []
        return "".join(b.get("text", "") for b in blocks if isinstance(b, dict))

    def _openai(self, client: httpx.Client, prompt: str, system: str | None) -> str:
        headers = {"content-type": "application/json"}
        if self.api_key:
            headers["authorization"] = f"Bearer {self.api_key}"
        messages = []
        if system:
            messages.append({"role": "system", "content": system})
        messages.append({"role": "user", "content": prompt})
        body = {"model": self.model, "messages": messages, "max_tokens": _MAX_TOKENS}
        resp = client.post(
            f"{self.base_url}/chat/completions", json=body, headers=headers
        )
        resp.raise_for_status()
        data = resp.json()
        try:
            return data["choices"][0]["message"]["content"] or ""
        except (KeyError, IndexError, TypeError):
            return ""
