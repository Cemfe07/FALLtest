"""
FCM ile "yorum hazır" push bildirimi.
FIREBASE_CREDENTIALS_JSON ortam değişkeni set değilse gönderim yapılmaz.
"""
from __future__ import annotations

import json
import logging
from typing import Optional

from app.core.config import settings
from app.db import engine
from app.repositories import profile_repo
from sqlmodel import Session

log = logging.getLogger("lunaura.fcm")

_firebase_initialized = False


def _ensure_firebase() -> bool:
    global _firebase_initialized
    if _firebase_initialized:
        return True
    creds_json = (settings.firebase_credentials_json or "").strip()
    if not creds_json:
        return False
    try:
        import firebase_admin
        from firebase_admin import credentials

        creds_dict = json.loads(creds_json)
        firebase_admin.initialize_app(credentials.Certificate(creds_dict))
        _firebase_initialized = True
        return True
    except Exception as e:
        log.warning("Firebase init failed (FCM disabled): %s", e)
        return False


def send_reading_ready_notification(device_id: str) -> None:
    """
    Cihaza "Yorumunuz hazır" push bildirimi gönderir.
    device_id'ye kayıtlı fcm_token yoksa veya FCM yapılandırılmamışsa sessizce çıkar.
    """
    if not _ensure_firebase():
        return
    try:
        from firebase_admin import messaging

        with Session(engine) as session:
            profile = profile_repo.get_by_device(session, device_id)
            if not profile or not (getattr(profile, "fcm_token", None) or "").strip():
                return
            token = (profile.fcm_token or "").strip()

        message = messaging.Message(
            notification=messaging.Notification(
                title="Yorumunuz hazır!",
                body="Benim Okumalarım'dan ulaşabilirsiniz.",
            ),
            token=token,
        )
        messaging.send(message)
        log.info("FCM sent to device_id=%s", device_id[:8] + "...")
    except Exception as e:
        if "UnregisteredError" in type(e).__name__ or "invalid" in str(e).lower():
            log.warning("FCM token invalid/unregistered for device_id=%s", device_id[:8] + "...")
        else:
            log.exception("FCM send failed for device_id=%s: %s", device_id[:8] + "...", e)


def send_daily_reminder_to_all() -> int:
    """
    FCM token'ı kayıtlı tüm cihazlara günlük hatırlatma push'u gönderir.
    Cron tarafından günde bir kez çağrılır. Gönderilen mesaj sayısını döner.
    """
    if not _ensure_firebase():
        return 0
    try:
        from firebase_admin import messaging

        with Session(engine) as session:
            tokens_list = profile_repo.get_all_with_fcm_token(session)

        sent = 0
        for device_id, token in tokens_list:
            try:
                message = messaging.Message(
                    notification=messaging.Notification(
                        title="Günlük falınız sizi bekliyor!",
                        body="LunAura ile gününüzü keşfedin.",
                    ),
                    token=token,
                )
                messaging.send(message)
                sent += 1
                log.info("FCM daily reminder sent to device_id=%s", (device_id or "")[:8] + "...")
            except Exception as e:
                if "UnregisteredError" in type(e).__name__ or "invalid" in str(e).lower():
                    log.warning("FCM token invalid, skip device_id=%s", (device_id or "")[:8] + "...")
                else:
                    log.warning("FCM daily send failed for device_id=%s: %s", (device_id or "")[:8] + "...", e)
        return sent
    except Exception as e:
        log.exception("FCM send_daily_reminder_to_all failed: %s", e)
        return 0
