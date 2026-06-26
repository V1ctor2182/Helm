"""Email REST. m1: account CRUD (encrypted creds) + inbox list + IMAP sync."""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from sqlalchemy import select

from helm.app import db_session, get_memory_vectors, get_secret_box
from helm.chat.models import Provider
from helm.chat.service import ProviderService
from helm.crypto import SecretBox
from helm.mail import models  # noqa: F401  (register tables on Base)
from helm.mail.imap import ImaplibFetcher
from helm.mail.service import (
    AccountService,
    EmailService,
    account_public,
    email_public,
)
from helm.research.llm import ChatLLM  # patched in tests

router = APIRouter(prefix="/api/mail", tags=["mail"])

# Module-level so tests can patch in a fake fetcher (avoids real IMAP).
default_fetcher = ImaplibFetcher()


class AccountBody(BaseModel):
    name: str
    email_addr: str
    imap_host: str
    username: str
    password: str
    imap_port: int = 993
    smtp_host: str = ""
    smtp_port: int = 587


@router.get("/accounts")
def list_accounts(
    session: Session = Depends(db_session), box: SecretBox = Depends(get_secret_box)
) -> dict:
    return {"accounts": [account_public(a) for a in AccountService(session, box).list()]}


@router.post("/accounts")
def create_account(
    body: AccountBody,
    session: Session = Depends(db_session),
    box: SecretBox = Depends(get_secret_box),
) -> dict:
    account = AccountService(session, box).create(
        name=body.name, email_addr=body.email_addr, imap_host=body.imap_host,
        username=body.username, password=body.password, imap_port=body.imap_port,
        smtp_host=body.smtp_host, smtp_port=body.smtp_port,
    )
    return account_public(account)


@router.delete("/accounts/{account_id}")
def delete_account(
    account_id: int,
    session: Session = Depends(db_session),
    box: SecretBox = Depends(get_secret_box),
) -> dict:
    if not AccountService(session, box).delete(account_id):
        raise HTTPException(status_code=404, detail="account not found")
    return {"deleted": account_id}


@router.post("/accounts/{account_id}/sync")
def sync_account(
    account_id: int,
    session: Session = Depends(db_session),
    box: SecretBox = Depends(get_secret_box),
) -> dict:
    accounts = AccountService(session, box)
    account = accounts.get(account_id)
    if account is None:
        raise HTTPException(status_code=404, detail="account not found")
    password = accounts.password(account_id) or ""
    try:
        new = EmailService(session).sync(account, password, default_fetcher)
    except Exception as exc:  # noqa: BLE001 - surface IMAP errors as 502
        raise HTTPException(status_code=502, detail=f"IMAP sync failed: {exc}")
    return {"new": new}


@router.get("/emails")
def list_emails(
    account_id: int | None = Query(default=None),
    unread_only: bool = Query(default=False),
    session: Session = Depends(db_session),
) -> dict:
    emails = EmailService(session).list(account_id=account_id, unread_only=unread_only)
    return {"emails": [email_public(e) for e in emails]}


@router.get("/emails/{email_id}")
def get_email(email_id: int, session: Session = Depends(db_session)) -> dict:
    email = EmailService(session).get(email_id)
    if email is None:
        raise HTTPException(status_code=404, detail="email not found")
    return {**email_public(email), "body": email.body}


class TriageBody(BaseModel):
    provider_id: int
    model: str


@router.post("/emails/{email_id}/triage")
def triage_email_route(
    email_id: int,
    body: TriageBody,
    session: Session = Depends(db_session),
    box: SecretBox = Depends(get_secret_box),
) -> dict:
    """AI triage (intent#1): urgency / summary / labels / spam / draft reply.
    The LLM call is paid but user-initiated."""
    if EmailService(session).get(email_id) is None:
        raise HTTPException(status_code=404, detail="email not found")
    provider = session.scalar(select(Provider).where(Provider.id == body.provider_id))
    if provider is None:
        raise HTTPException(status_code=404, detail="provider not found")
    key = ProviderService(session, box).api_key(body.provider_id)
    llm = ChatLLM(provider.type, provider.base_url, body.model, key)
    return EmailService(session).triage(email_id, llm)


@router.post("/emails/{email_id}/to-memory")
def email_to_memory(
    email_id: int,
    session: Session = Depends(db_session),
    vectors=Depends(get_memory_vectors),
) -> dict:
    from helm.memory.service import MemoryService

    out = EmailService(session).to_memory(email_id, MemoryService(session, vectors))
    if out is None:
        raise HTTPException(status_code=404, detail="email not found")
    return out


class EmailToEventBody(BaseModel):
    start: datetime
    end: datetime | None = None


@router.post("/emails/{email_id}/to-event")
def email_to_event(
    email_id: int, body: EmailToEventBody, session: Session = Depends(db_session)
) -> dict:
    """Turn an email into a calendar event (intent#3 email→日历事件): subject →
    summary, body → description, the user-picked time → start."""
    from helm.calendar.service import EventService, event_public

    email = EmailService(session).get(email_id)
    if email is None:
        raise HTTPException(status_code=404, detail="email not found")
    event = EventService(session).create(
        summary=email.subject or "(邮件事件)",
        description=(email.body or "")[:2000],
        start=body.start,
        end=body.end,
        source="local",
    )
    return event_public(event)


class EmailToTaskBody(BaseModel):
    schedule_kind: str
    schedule_value: dict


@router.post("/emails/{email_id}/to-task")
def email_to_task(
    email_id: int, body: EmailToTaskBody, session: Session = Depends(db_session)
) -> dict:
    """Schedule an agent task to handle this email (intent#3 email→task)."""
    from helm.tasks.service import TaskService, task_public

    email = EmailService(session).get(email_id)
    if email is None:
        raise HTTPException(status_code=404, detail="email not found")
    prompt = f"处理这封邮件并回复:\n主题: {email.subject}\n发件人: {email.from_addr}\n\n{email.body}"
    try:
        task = TaskService(session).create(
            f"回复:{email.subject[:30]}", prompt, body.schedule_kind, body.schedule_value,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc))
    return task_public(task)
