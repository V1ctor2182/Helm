"""Chat REST. m1: provider management + built-in templates. Streaming chat
(m3) is added later."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from helm.app import db_session, get_secret_box
from helm.chat import models  # noqa: F401  (register Provider on Base.metadata)
from helm.chat.service import PROVIDER_TEMPLATES, ProviderService, provider_public
from helm.crypto import SecretBox

router = APIRouter(prefix="/api", tags=["chat"])


class ProviderBody(BaseModel):
    type: str
    name: str
    base_url: str = ""
    api_key: str | None = None
    models: list[str] | None = None


@router.get("/providers/templates")
def provider_templates() -> dict:
    return {"templates": PROVIDER_TEMPLATES}


@router.get("/providers")
def list_providers(
    session: Session = Depends(db_session),
    box: SecretBox = Depends(get_secret_box),
) -> dict:
    providers = ProviderService(session, box).list()
    return {"providers": [provider_public(p) for p in providers]}


@router.post("/providers")
def create_provider(
    body: ProviderBody,
    session: Session = Depends(db_session),
    box: SecretBox = Depends(get_secret_box),
) -> dict:
    svc = ProviderService(session, box)
    provider = svc.create(
        type=body.type,
        name=body.name,
        base_url=body.base_url,
        api_key=body.api_key,
        models=body.models,
    )
    return provider_public(provider)


@router.delete("/providers/{provider_id}", status_code=204)
def delete_provider(
    provider_id: int,
    session: Session = Depends(db_session),
    box: SecretBox = Depends(get_secret_box),
) -> None:
    if not ProviderService(session, box).delete(provider_id):
        raise HTTPException(status_code=404, detail="provider not found")
