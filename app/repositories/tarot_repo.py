from __future__ import annotations

from datetime import datetime, timedelta
from typing import Optional, List

from sqlmodel import Session, select
from sqlalchemy import update, and_, or_

from app.models.tarot_db import TarotReadingDB


def create_reading(session: Session, obj: TarotReadingDB) -> TarotReadingDB:
    session.add(obj)
    session.commit()
    session.refresh(obj)
    return obj


def get_reading(session: Session, reading_id: str) -> Optional[TarotReadingDB]:
    stmt = select(TarotReadingDB).where(TarotReadingDB.id == reading_id)
    return session.exec(stmt).first()


def update_reading(session: Session, obj: TarotReadingDB) -> TarotReadingDB:
    obj.updated_at = datetime.utcnow()
    session.add(obj)
    session.commit()
    session.refresh(obj)
    return obj


def set_device_id(session: Session, reading_id: str, device_id: str) -> TarotReadingDB:
    r = get_reading(session, reading_id)
    if not r:
        raise KeyError("not_found")
    r.device_id = device_id
    return update_reading(session, r)


def set_cards(session: Session, reading_id: str, cards: List[str]) -> TarotReadingDB:
    r = get_reading(session, reading_id)
    if not r:
        raise KeyError("not_found")

    r.set_cards(cards)
    r.status = "selected"
    return update_reading(session, r)


def set_status(
    session: Session,
    reading_id: str,
    status: str,
    result_text: Optional[str] = None,
) -> TarotReadingDB:
    r = get_reading(session, reading_id)
    if not r:
        raise KeyError("not_found")

    r.status = status
    if result_text is not None:
        r.result_text = result_text

    return update_reading(session, r)


def claim_processing(session: Session, reading_id: str, *, stale_seconds: int = 120) -> bool:
    """
    ✅ Atomic "processing lock"

    - completed ise dokunmaz.
    - processing ise dokunmaz (ama stale ise reclaim eder).
    - paid/selected gibi durumlarda processing'e geçirir.
    """
    now = datetime.utcnow()
    stale_cutoff = now - timedelta(seconds=int(stale_seconds or 120))

    can_claim = or_(
        TarotReadingDB.status != "processing",
        and_(TarotReadingDB.status == "processing", TarotReadingDB.updated_at < stale_cutoff),
    )

    stmt = (
        update(TarotReadingDB)
        .where(TarotReadingDB.id == reading_id)
        .where(TarotReadingDB.status != "completed")
        .where(can_claim)
        .values(status="processing", updated_at=now)
    )

    res = session.exec(stmt)
    session.commit()

    # rowcount bazı driverlarda None dönebiliyor
    rc = getattr(res, "rowcount", None)
    if rc is not None:
        return bool(rc > 0)

    # fallback: yeniden oku
    r = get_reading(session, reading_id)
    if not r:
        return False

    return (r.status == "processing") and ((now - (r.updated_at or now)).total_seconds() < 5)
