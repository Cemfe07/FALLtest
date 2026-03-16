# app/repositories/birthchart_repo.py
from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlmodel import Session, select

from app.models.birthchart_db import BirthChartReadingDB


def _dump(obj: BirthChartReadingDB) -> dict:
    return {
        "id": obj.id,
        "device_id": obj.device_id,
        "topic": obj.topic,
        "question": obj.question,
        "name": obj.name,
        "birth_date": obj.birth_date,
        "birth_time": obj.birth_time,
        "birth_city": obj.birth_city,
        "birth_country": obj.birth_country,
        "status": obj.status,
        "result_text": obj.result_text,
        "rating": obj.rating,
        "is_paid": obj.is_paid,
        "payment_ref": obj.payment_ref,
        "created_at": obj.created_at,
        "updated_at": obj.updated_at,
    }


def create_reading(session: Session, obj: BirthChartReadingDB) -> BirthChartReadingDB:
    session.add(obj)
    session.commit()
    session.refresh(obj)
    return obj


def get_reading(session: Session, reading_id: str) -> Optional[BirthChartReadingDB]:
    stmt = select(BirthChartReadingDB).where(BirthChartReadingDB.id == reading_id)
    return session.exec(stmt).first()


def update_reading(session: Session, obj: BirthChartReadingDB) -> BirthChartReadingDB:
    obj.updated_at = datetime.utcnow()
    session.add(obj)
    session.commit()
    session.refresh(obj)
    return obj


def mark_paid_low(session: Session, reading_id: str, payment_ref: Optional[str]) -> BirthChartReadingDB:
    obj = get_reading(session, reading_id)
    if not obj:
        raise ValueError("Reading not found")

    obj.is_paid = True
    obj.payment_ref = payment_ref
    obj.status = "paid"
    return update_reading(session, obj)


def set_result_low(session: Session, reading_id: str, result_text: str) -> BirthChartReadingDB:
    obj = get_reading(session, reading_id)
    if not obj:
        raise ValueError("Reading not found")

    obj.result_text = result_text
    obj.status = "done"  # ✅ completed yerine done
    return update_reading(session, obj)


def set_status_low(session: Session, reading_id: str, status: str) -> BirthChartReadingDB:
    obj = get_reading(session, reading_id)
    if not obj:
        raise ValueError("Reading not found")

    obj.status = status
    return update_reading(session, obj)


class BirthChartRepo:
    def create(
        self,
        *,
        session: Session,
        reading_id: str,
        device_id: str,
        name: str,
        birth_date: str,
        birth_time: Optional[str],
        birth_city: str,
        birth_country: str,
        topic: str,
        question: Optional[str],
    ) -> dict:
        obj = BirthChartReadingDB(
            id=reading_id,
            device_id=device_id,
            name=name,
            birth_date=birth_date,
            birth_time=birth_time,
            birth_city=birth_city,
            birth_country=birth_country,
            topic=topic or "genel",
            question=question,
            status="started",
            is_paid=False,
        )
        created = create_reading(session, obj)
        return _dump(created)

    def get(self, *, session: Session, reading_id: str) -> Optional[dict]:
        obj = get_reading(session, reading_id)
        return _dump(obj) if obj else None

    def mark_paid(self, *, session: Session, reading_id: str, payment_ref: Optional[str]) -> Optional[dict]:
        try:
            obj = mark_paid_low(session, reading_id, payment_ref)
            return _dump(obj)
        except Exception:
            return None

    def set_status(self, *, session: Session, reading_id: str, status: str) -> Optional[dict]:
        try:
            obj = set_status_low(session, reading_id, status)
            return _dump(obj)
        except Exception:
            return None

    def set_result(self, *, session: Session, reading_id: str, result_text: str) -> Optional[dict]:
        try:
            obj = set_result_low(session, reading_id, result_text)
            return _dump(obj)
        except Exception:
            return None


birthchart_repo = BirthChartRepo()
