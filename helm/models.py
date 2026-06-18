"""Core ORM models owned by platform-shell.

Only the generic key-value ``settings`` table lives here. Feature rooms define
their own tables in their own modules (and import :class:`helm.db.Base`); their
schemas are single-way-door decisions made in those rooms, not here.
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from helm.db import Base


class Setting(Base):
    """A single application setting, stored as a string key/value pair.

    The encrypted-secret store and the typed settings service are built on top
    of this in m3; m2 only provides the table so storage is verifiable
    end-to-end.
    """

    __tablename__ = "settings"

    key: Mapped[str] = mapped_column(String(255), primary_key=True)
    value: Mapped[str] = mapped_column(Text, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    def __repr__(self) -> str:  # pragma: no cover - debug aid
        return f"Setting(key={self.key!r})"


class Secret(Base):
    """An encrypted secret (e.g. an API key).

    ``value`` is ALWAYS Fernet ciphertext (``enc:`` prefix) — plaintext must
    never be written here (constraint: API keys must not land in the DB in
    plaintext). Kept in its own table, separate from :class:`Setting`, so the
    "ciphertext only" invariant is structural rather than per-call discipline.
    """

    __tablename__ = "secrets"

    key: Mapped[str] = mapped_column(String(255), primary_key=True)
    value: Mapped[str] = mapped_column(Text, nullable=False)  # ciphertext only
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    def __repr__(self) -> str:  # pragma: no cover - debug aid
        return f"Secret(key={self.key!r})"
