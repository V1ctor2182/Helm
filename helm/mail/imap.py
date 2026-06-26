"""IMAP fetch layer. The engine/sync only depends on the ``ImapFetcher``
Protocol, so tests drive sync with a fake (no real mailbox). ``ImaplibFetcher``
is the real one (stdlib imaplib) — external, used at runtime, never in the loop.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Protocol


@dataclass
class FetchedEmail:
    uid: str
    from_addr: str = ""
    subject: str = ""
    body: str = ""
    date: datetime | None = None
    unread: bool = True

    @property
    def snippet(self) -> str:
        return " ".join(self.body.split())[:200]


class ImapFetcher(Protocol):
    def fetch(self, account, password: str, limit: int = 50) -> list[FetchedEmail]:
        """Return recent messages from the account's INBOX."""
        ...


class ImaplibFetcher:  # pragma: no cover - real network, exercised manually
    """Real IMAP fetch via stdlib imaplib. Not run in tests/loop (external)."""

    def fetch(self, account, password: str, limit: int = 50) -> list[FetchedEmail]:
        import email as email_lib
        import imaplib
        from email.utils import parsedate_to_datetime

        out: list[FetchedEmail] = []
        client = imaplib.IMAP4_SSL(account.imap_host, account.imap_port)
        try:
            client.login(account.username, password)
            client.select("INBOX")
            typ, data = client.uid("search", None, "ALL")
            uids = (data[0].split() if data and data[0] else [])[-limit:]
            for raw_uid in reversed(uids):
                uid = raw_uid.decode()
                typ, msg_data = client.uid("fetch", raw_uid, "(RFC822 FLAGS)")
                if not msg_data or not msg_data[0]:
                    continue
                msg = email_lib.message_from_bytes(msg_data[0][1])
                flags = str(msg_data[0][0])
                body = _plain_body(msg)
                try:
                    when = parsedate_to_datetime(msg.get("Date"))
                except (TypeError, ValueError):
                    when = None
                out.append(
                    FetchedEmail(
                        uid=uid,
                        from_addr=str(msg.get("From", "")),
                        subject=str(msg.get("Subject", "")),
                        body=body,
                        date=when,
                        unread="\\Seen" not in flags,
                    )
                )
        finally:
            try:
                client.logout()
            except Exception:
                pass
        return out


def _plain_body(msg) -> str:  # pragma: no cover - real-message parsing
    if msg.is_multipart():
        for part in msg.walk():
            if part.get_content_type() == "text/plain":
                payload = part.get_payload(decode=True)
                if payload:
                    return payload.decode(part.get_content_charset() or "utf-8", "replace")
        return ""
    payload = msg.get_payload(decode=True)
    return payload.decode(msg.get_content_charset() or "utf-8", "replace") if payload else ""
