"""
FCM token kaydı: uygulama açılışında token backend'e gönderilir.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.core.device import get_device_id
from app.db import get_session
from app.repositories import profile_repo
from sqlmodel import Session

router = APIRouter(prefix="/notifications", tags=["notifications"])


class RegisterFcmRequest(BaseModel):
    fcm_token: str


@router.post("/register")
def register_fcm(
    req: RegisterFcmRequest,
    device_id: str = Depends(get_device_id),
    session: Session = Depends(get_session),
):
    token = (req.fcm_token or "").strip()
    if not token:
        return {"ok": False, "detail": "fcm_token boş"}
    profile_repo.set_fcm_token(session, device_id, token)
    return {"ok": True}
