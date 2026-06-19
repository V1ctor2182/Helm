"""Chat REST. m1: provider management + built-in templates. Streaming chat
(m3) is added later."""

from __future__ import annotations

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from helm.app import db_session, get_secret_box
from helm.chat import adapters
from helm.chat import models  # noqa: F401  (register Provider on Base.metadata)
from helm.chat.models import Provider
from helm.chat.service import PROVIDER_TEMPLATES, ProviderService, provider_public
from helm.crypto import DecryptionError, SecretBox

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


@router.post("/providers/{provider_id}/test")
async def test_provider(
    provider_id: int,
    session: Session = Depends(db_session),
    box: SecretBox = Depends(get_secret_box),
) -> dict:
    """Ping a provider for connectivity + model discovery."""
    svc = ProviderService(session, box)
    provider = session.get(Provider, provider_id)
    if provider is None:
        raise HTTPException(status_code=404, detail="provider not found")
    try:
        key = svc.api_key(provider_id)  # may raise DecryptionError on a lost key
        available = await adapters.ping(
            provider_type=provider.type, base_url=provider.base_url, api_key=key
        )
        return {"ok": True, "models": available}
    except (httpx.HTTPError, DecryptionError) as exc:
        return {"ok": False, "error": str(exc)}


@router.delete("/providers/{provider_id}", status_code=204)
def delete_provider(
    provider_id: int,
    session: Session = Depends(db_session),
    box: SecretBox = Depends(get_secret_box),
) -> None:
    if not ProviderService(session, box).delete(provider_id):
        raise HTTPException(status_code=404, detail="provider not found")
