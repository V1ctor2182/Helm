"""Chat ORM models. m1 ships `providers`; `sessions`/`messages`/`presets` land
in m3 with streaming chat (their schemas per F2 §5)."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, String, Text, func
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
