"""Provider registry: CRUD with encrypted keys + built-in provider templates.
Keys are encrypted via SecretBox on save and never returned to the client.
"""

from __future__ import annotations

import json

from sqlalchemy import select
from sqlalchemy.orm import Session

from helm.chat.models import Provider
from helm.crypto import SecretBox

# Built-in provider presets (suggested configs). Claude is the default, aligned
# with the Claude Code agent route (F5). Model lists are starting points;
# real discovery happens on test/ping (m2).
PROVIDER_TEMPLATES: list[dict] = [
    {
        "type": "anthropic",
        "name": "Claude",
        "base_url": "https://api.anthropic.com",
        "needs_key": True,
        "models": ["claude-opus-4-8", "claude-sonnet-4-6", "claude-haiku-4-5-20251001"],
        "default": True,
    },
    {
        "type": "ollama",
        "name": "Ollama",
        "base_url": "http://localhost:11434",
        "needs_key": False,
        "models": [],
    },
    {
        "type": "openai",
        "name": "OpenAI",
        "base_url": "https://api.openai.com/v1",
        "needs_key": True,
        "models": ["gpt-4o", "gpt-4o-mini"],
    },
    {
        "type": "openrouter",
        "name": "OpenRouter",
        "base_url": "https://openrouter.ai/api/v1",
        "needs_key": True,
        "models": [],
    },
    {
        "type": "openai-compat",
        "name": "OpenAI 兼容",
        "base_url": "",
        "needs_key": False,
        "models": [],
    },
]


def provider_public(p: Provider) -> dict:
    """Serialize a provider WITHOUT exposing the key (just whether one is set)."""
    return {
        "id": p.id,
        "type": p.type,
        "name": p.name,
        "base_url": p.base_url,
        "models": json.loads(p.models_json),
        "has_key": p.api_key_enc is not None,
    }


class ProviderService:
    def __init__(self, session: Session, box: SecretBox) -> None:
        self._session = session
        self._box = box

    def list(self) -> list[Provider]:
        return list(
            self._session.execute(select(Provider).order_by(Provider.id)).scalars()
        )

    def create(
        self,
        type: str,
        name: str,
        base_url: str = "",
        api_key: str | None = None,
        models: list[str] | None = None,
    ) -> Provider:
        provider = Provider(
            type=type,
            name=name,
            base_url=base_url,
            api_key_enc=self._box.encrypt(api_key) if api_key else None,
            models_json=json.dumps(models or []),
        )
        self._session.add(provider)
        self._session.flush()
        return provider

    def delete(self, provider_id: int) -> bool:
        row = self._session.get(Provider, provider_id)
        if row is None:
            return False
        self._session.delete(row)
        return True

    def api_key(self, provider_id: int) -> str | None:
        """Decrypted key for server-side use (adapters, m2). Never sent to UI."""
        row = self._session.get(Provider, provider_id)
        if row is None or row.api_key_enc is None:
            return None
        return self._box.decrypt(row.api_key_enc)
