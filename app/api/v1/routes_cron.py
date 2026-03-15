"""
Cron endpoint'leri: dış scheduler (örn. cron-job.org) günde bir bu URL'yi çağırır.
"""
from __future__ import annotations

from fastapi import APIRouter, Header, HTTPException

from app.core.config import settings
from app.services import fcm_service

router = APIRouter(prefix="/cron", tags=["cron"])


def _check_cron_secret(x_cron_secret: str | None = Header(default=None, alias="X-Cron-Secret")) -> None:
    secret = (settings.cron_secret or "").strip()
    if not secret:
        raise HTTPException(status_code=503, detail="Cron not configured")
    token = (x_cron_secret or "").strip()
    if token != secret:
        raise HTTPException(status_code=403, detail="Invalid cron secret")


@router.post("/daily-reminder")
def daily_reminder(x_cron_secret: str | None = Header(default=None, alias="X-Cron-Secret")):
    """FCM token'ı olan tüm kullanıcılara günlük hatırlatma push'u gönderir. Günde bir kez çağrılmalı."""
    _check_cron_secret(x_cron_secret)
    sent = fcm_service.send_daily_reminder_to_all()
    return {"ok": True, "sent": sent}
