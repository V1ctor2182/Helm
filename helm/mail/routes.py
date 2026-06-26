"""Email REST. m1: account CRUD (encrypted creds) + inbox list + IMAP sync."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from sqlalchemy import select

from helm.app import db_session, get_secret_box
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
