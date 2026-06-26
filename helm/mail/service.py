"""Email account + inbox service. Credentials are SecretBox-encrypted on save
and never returned (constraint 9ada9908). Sync upserts fetched messages by
(account, uid) so re-syncing doesn't duplicate."""

from __future__ import annotations

import json

from sqlalchemy import select
from sqlalchemy.orm import Session

from helm.crypto import SecretBox
from helm.mail.imap import FetchedEmail, ImapFetcher
from helm.mail.models import Email, EmailAccount


def account_public(a: EmailAccount) -> dict:
    return {
        "id": a.id,
        "name": a.name,
        "email_addr": a.email_addr,
        "imap_host": a.imap_host,
        "imap_port": a.imap_port,
        "smtp_host": a.smtp_host,
        "smtp_port": a.smtp_port,
        "username": a.username,
        "has_password": bool(a.password_enc),  # never the password itself
        "created_at": a.created_at.isoformat() if a.created_at else None,
    }


def email_public(e: Email) -> dict:
    return {
        "id": e.id,
        "account_id": e.account_id,
        "uid": e.uid,
        "from_addr": e.from_addr,
        "subject": e.subject,
        "snippet": e.snippet,
        "unread": e.unread,
        "labels": json.loads(e.labels_json or "[]"),
        "triage": json.loads(e.triage_json) if e.triage_json else None,
        "date": e.date.isoformat() if e.date else None,
    }


class AccountService:
    def __init__(self, session: Session, box: SecretBox) -> None:
        self.session = session
        self.box = box

    def list(self) -> list[EmailAccount]:
        return list(
            self.session.scalars(
                select(EmailAccount).order_by(EmailAccount.created_at.desc())
            )
        )

    def get(self, account_id: int) -> EmailAccount | None:
        return self.session.get(EmailAccount, account_id)

    def create(
        self,
        *,
        name: str,
        email_addr: str,
        imap_host: str,
        username: str,
        password: str,
        imap_port: int = 993,
        smtp_host: str = "",
        smtp_port: int = 587,
    ) -> EmailAccount:
        account = EmailAccount(
            name=name,
            email_addr=email_addr,
            imap_host=imap_host,
            imap_port=imap_port,
            smtp_host=smtp_host,
            smtp_port=smtp_port,
            username=username,
            password_enc=self.box.encrypt(password),  # ciphertext only
        )
        self.session.add(account)
        self.session.flush()
        return account

    def password(self, account_id: int) -> str | None:
        account = self.get(account_id)
        if account is None or not account.password_enc:
            return None
        return self.box.decrypt(account.password_enc)

    def delete(self, account_id: int) -> bool:
        account = self.get(account_id)
        if account is None:
            return False
        for e in self.session.scalars(
            select(Email).where(Email.account_id == account_id)
        ):
            self.session.delete(e)
        self.session.delete(account)
        return True


class EmailService:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list(self, account_id: int | None = None, unread_only: bool = False) -> list[Email]:
        stmt = select(Email).order_by(Email.date.desc().nullslast(), Email.id.desc())
        if account_id is not None:
            stmt = stmt.where(Email.account_id == account_id)
        if unread_only:
            stmt = stmt.where(Email.unread.is_(True))
        return list(self.session.scalars(stmt))

    def get(self, email_id: int) -> Email | None:
        return self.session.get(Email, email_id)

    def sync(self, account: EmailAccount, password: str, fetcher: ImapFetcher, limit: int = 50) -> int:
        """Fetch + upsert by (account, uid). Returns count of NEW emails."""
        fetched = fetcher.fetch(account, password, limit)
        existing = {
            e.uid
            for e in self.session.scalars(
                select(Email).where(Email.account_id == account.id)
            )
        }
        new = 0
        for f in fetched:
            if f.uid in existing:
                continue
            self.session.add(self._row(account.id, f))
            new += 1
        self.session.flush()
        return new

    @staticmethod
    def _row(account_id: int, f: FetchedEmail) -> Email:
        return Email(
            account_id=account_id,
            uid=f.uid,
            from_addr=f.from_addr,
            subject=f.subject,
            snippet=f.snippet,
            body=f.body,
            date=f.date,
            unread=f.unread,
        )
