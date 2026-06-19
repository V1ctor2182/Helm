"""Chat ORM models. m1 ships `providers`; `sessions`/`messages`/`presets` land
in m3 with streaming chat (their schemas per F2 §5)."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from helm.db import Base


class Provider(Base):
    """A configured model provider. ``api_key_enc`` is SecretBox ciphertext
    (never plaintext — constraint 6a745b5c); null for keyless (e.g. Ollama).
    ``models_json`` is the JSON list of model ids this provider exposes."""

    __tablename__ = "providers"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    type: Mapped[str] = mapped_column(String(40), nullable=False)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    base_url: Mapped[str] = mapped_column(String, nullable=False, default="")
    api_key_enc: Mapped[str | None] = mapped_column(Text, nullable=True)
    models_json: Mapped[str] = mapped_column(Text, nullable=False, default="[]")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class ChatSession(Base):
    """A chat conversation, pinned to a provider + model + system prompt so it
    restores faithfully (constraint e9ddc41a). `presets` (reusable prompts) is
    deferred to m4 with the UI."""

    __tablename__ = "sessions"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    kind: Mapped[str] = mapped_column(String(20), nullable=False, default="chat")
    title: Mapped[str | None] = mapped_column(String, nullable=True)
    project_path: Mapped[str | None] = mapped_column(String, nullable=True)
    provider_id: Mapped[int] = mapped_column(ForeignKey("providers.id"), nullable=False)
    model: Mapped[str] = mapped_column(String, nullable=False)
    system_prompt: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class Message(Base):
    __tablename__ = "messages"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    session_id: Mapped[int] = mapped_column(
        ForeignKey("sessions.id"), nullable=False, index=True
    )
    role: Mapped[str] = mapped_column(String(20), nullable=False)  # user|assistant
    content: Mapped[str] = mapped_column(Text, nullable=False)
    ts: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
