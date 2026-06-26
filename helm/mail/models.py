"""Email ORM: accounts (encrypted creds) + fetched messages.

``password_enc`` is ALWAYS SecretBox ciphertext (constraint 9ada9908 — IMAP/SMTP
creds encrypted at rest); plaintext must never be written or returned. Emails are
cached locally (local-first) keyed by (account, uid)."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from helm.db import Base


class EmailAccount(Base):
    __tablename__ = "email_accounts"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    email_addr: Mapped[str] = mapped_column(String, nullable=False)
    imap_host: Mapped[str] = mapped_column(String, nullable=False)
    imap_port: Mapped[int] = mapped_column(Integer, nullable=False, default=993)
    smtp_host: Mapped[str] = mapped_column(String, nullable=False, default="")
    smtp_port: Mapped[int] = mapped_column(Integer, nullable=False, default=587)
    username: Mapped[str] = mapped_column(String, nullable=False)
    password_enc: Mapped[str] = mapped_column(Text, nullable=False)  # ciphertext only
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class Email(Base):
    __tablename__ = "emails"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    account_id: Mapped[int] = mapped_column(
        ForeignKey("email_accounts.id"), nullable=False, index=True
    )
    uid: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    from_addr: Mapped[str] = mapped_column(String, nullable=False, default="")
    subject: Mapped[str] = mapped_column(String, nullable=False, default="")
    snippet: Mapped[str] = mapped_column(Text, nullable=False, default="")
    body: Mapped[str] = mapped_column(Text, nullable=False, default="")
    date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    unread: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    labels_json: Mapped[str] = mapped_column(Text, nullable=False, default="[]")
    # AI triage result (m2): {urgency, summary, is_spam, labels, draft} — null until triaged.
    triage_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
