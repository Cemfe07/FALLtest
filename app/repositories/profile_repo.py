from __future__ import annotations

from datetime import datetime
from typing import List, Optional, Tuple

from sqlmodel import Session, select

from app.models.profile_db import UserProfileDB


def get_by_device(session: Session, device_id: str) -> Optional[UserProfileDB]:
    stmt = select(UserProfileDB).where(UserProfileDB.device_id == device_id)
    return session.exec(stmt).first()


def upsert_by_device(session: Session, device_id: str, data: dict) -> UserProfileDB:
    obj = get_by_device(session, device_id)
    now = datetime.utcnow()

    if obj is None:
        obj = UserProfileDB(device_id=device_id, **data)
        obj.created_at = now
        obj.updated_at = now
        session.add(obj)
        session.commit()
        session.refresh(obj)
        return obj

    for k, v in data.items():
        setattr(obj, k, v)
    obj.updated_at = now

    session.add(obj)
    session.commit()
    session.refresh(obj)
    return obj


def set_fcm_token(session: Session, device_id: str, fcm_token: str) -> Optional[UserProfileDB]:
    obj = get_by_device(session, device_id)
    now = datetime.utcnow()
    if obj is None:
        obj = UserProfileDB(device_id=device_id, fcm_token=fcm_token)
        obj.created_at = now
        obj.updated_at = now
        session.add(obj)
        session.commit()
        session.refresh(obj)
        return obj
    obj.fcm_token = fcm_token
    obj.updated_at = now
    session.add(obj)
    session.commit()
    session.refresh(obj)
    return obj


def get_all_with_fcm_token(session: Session) -> List[Tuple[str, str]]:
    """(device_id, fcm_token) listesi; token'ı boş olanlar dahil değil."""
    stmt = select(UserProfileDB).where(
        UserProfileDB.fcm_token.isnot(None),
        UserProfileDB.fcm_token != "",
    )
    profiles = list(session.exec(stmt).all())
    return [(p.device_id, (p.fcm_token or "").strip()) for p in profiles if (p.fcm_token or "").strip()]
