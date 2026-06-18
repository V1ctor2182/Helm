"""Settings + secrets REST surface (minimal).

Secrets are write-only over the network: you can set, list (keys only), and
delete them, but plaintext values are never returned — only server-side code
(via :class:`helm.settings.SecretStore`) reads the decrypted value.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy.orm import Session

from helm.app import db_session, get_secret_box
from helm.crypto import SecretBox
from helm.settings import SecretStore, SettingsService

router = APIRouter(prefix="/api", tags=["settings"])


class ValueBody(BaseModel):
    value: str


# ---- settings (plaintext) -------------------------------------------------


@router.get("/settings")
def list_settings(session: Session = Depends(db_session)) -> dict[str, str]:
    return SettingsService(session).all()


@router.get("/settings/{key}")
def get_setting(key: str, session: Session = Depends(db_session)) -> dict:
    value = SettingsService(session).get(key)
    if value is None:
        raise HTTPException(status_code=404, detail="setting not found")
    return {"key": key, "value": value}


@router.put("/settings/{key}")
def put_setting(
    key: str, body: ValueBody, session: Session = Depends(db_session)
) -> dict:
    SettingsService(session).set(key, body.value)
    return {"key": key, "value": body.value}


@router.delete("/settings/{key}", status_code=204)
def delete_setting(key: str, session: Session = Depends(db_session)) -> None:
    if not SettingsService(session).delete(key):
        raise HTTPException(status_code=404, detail="setting not found")


# ---- secrets (encrypted, write-only over the wire) ------------------------


# The SecretBox is lazy (it only reads the key file on encrypt/decrypt), so
# injecting it on every secret route is cheap — list/delete won't touch the key.


@router.get("/secrets")
def list_secret_keys(
    session: Session = Depends(db_session),
    box: SecretBox = Depends(get_secret_box),
) -> dict:
    return {"keys": SecretStore(session, box).keys()}


@router.put("/secrets/{key}")
def put_secret(
    key: str,
    body: ValueBody,
    session: Session = Depends(db_session),
    box: SecretBox = Depends(get_secret_box),
) -> dict:
    SecretStore(session, box).set(key, body.value)
    return {"key": key, "configured": True}


@router.delete("/secrets/{key}", status_code=204)
def delete_secret(
    key: str,
    session: Session = Depends(db_session),
    box: SecretBox = Depends(get_secret_box),
) -> None:
    if not SecretStore(session, box).delete(key):
        raise HTTPException(status_code=404, detail="secret not found")
