# app/api/v1/routes_birthchart.py
from __future__ import annotations

from uuid import uuid4
from typing import Any, Dict

from fastapi import APIRouter, HTTPException, Depends
from sqlmodel import Session, select

from app.db import get_session
from app.core.device import get_device_id
from app.models.birthchart_db import BirthChartReadingDB
from app.schemas.birthchart import BirthChartStartRequest
from app.repositories.birthchart_repo import birthchart_repo
from app.services.birthchart_service import generate_birthchart_reading

router = APIRouter(prefix="/birthchart", tags=["birthchart"])


def _ensure_no_blocking_locked_reading(session: Session, device_id: str) -> None:
    stmt = (
        select(BirthChartReadingDB.id)
        .where(
            BirthChartReadingDB.device_id == device_id,
            BirthChartReadingDB.is_paid == False,  # noqa: E712
            BirthChartReadingDB.result_text.is_not(None),
            BirthChartReadingDB.result_text != "",
        )
        .order_by(BirthChartReadingDB.created_at.desc())
        .limit(1)
    )
    existing_id = session.exec(stmt).first()
    if existing_id:
        raise HTTPException(
            status_code=409,
            detail="Bu bölümde kilidi açılmamış hazır bir yorumunuz var. Yeni yorumdan önce mevcut yorumu açın.",
        )


@router.post("/start")
def start_birthchart(
    payload: BirthChartStartRequest,
    session: Session = Depends(get_session),
    device_id: str = Depends(get_device_id),
):
    _ensure_no_blocking_locked_reading(session, device_id)

    reading_id = str(uuid4())
    reading = birthchart_repo.create(
        session=session,
        reading_id=reading_id,
        device_id=device_id,
        name=payload.name,
        birth_date=payload.birth_date,
        birth_time=payload.birth_time,
        birth_city=payload.birth_city,
        birth_country=payload.birth_country,
        topic=payload.topic,
        question=payload.question,
    )
    return reading


@router.post("/{reading_id}/mark-paid")
def mark_paid(
    reading_id: str,
    payload: Dict[str, Any] | None = None,
    session: Session = Depends(get_session),
):
    """
    ✅ Legacy/mock akış bozulmasın diye endpoint duruyor.
    🔒 Ama güvenlik için sadece TEST-... (mock) ödeme ref ile çalışır.
    Real ödeme: /payments/verify server-side mark_paid yapar.
    """
    payment_ref = (payload or {}).get("payment_ref")

    if not payment_ref:
        raise HTTPException(status_code=422, detail="payment_ref is required")

    if not str(payment_ref).startswith("TEST-"):
        raise HTTPException(
            status_code=403,
            detail="mark-paid is legacy only. Use /payments/verify for real payments.",
        )

    reading = birthchart_repo.mark_paid(session=session, reading_id=reading_id, payment_ref=payment_ref)
    if not reading:
        raise HTTPException(status_code=404, detail="Reading not found")
    return reading


def _mask_result_if_unpaid(reading: Dict[str, Any]) -> Dict[str, Any]:
    """Ödeme yapılmamışsa result_text istemciye gönderilmez."""
    if not reading:
        return reading
    out = dict(reading)
    out["has_result"] = bool((out.get("result_text") or "").strip())
    if not out.get("is_paid"):
        out["result_text"] = None
    return out


@router.get("/{reading_id}")
def detail(
    reading_id: str,
    session: Session = Depends(get_session),
):
    reading = birthchart_repo.get(session=session, reading_id=reading_id)
    if not reading:
        raise HTTPException(status_code=404, detail="Reading not found")
    return _mask_result_if_unpaid(reading)


@router.post("/{reading_id}/generate")
def generate(
    reading_id: str,
    session: Session = Depends(get_session),
    device_id: str = Depends(get_device_id),
):
    reading = birthchart_repo.get(session=session, reading_id=reading_id)
    if not reading:
        raise HTTPException(status_code=404, detail="Reading not found")

    # Ödeme öncesi generate’e izin ver (yorum DB’de saklanır, _mask_result_if_unpaid ödenmemişse göstermez)
    status = (reading.get("status") or "").lower().strip()
    result_text = (reading.get("result_text") or "").strip()

    # ✅ idempotent: sonuç varsa direkt dön
    if result_text and status == "done":
        return _mask_result_if_unpaid(reading)

    # ✅ result var ama status farklıysa düzelt
    if result_text and status != "done":
        fixed = birthchart_repo.set_status(session=session, reading_id=reading_id, status="done")
        return _mask_result_if_unpaid(fixed or reading)

    # ✅ processing: Başka bir istek zaten yorum üretiyor; boş reading dönme, 409 ver ki istemci tekrar denesin.
    if status == "processing":
        raise HTTPException(
            status_code=409,
            detail="Yorum hazırlanıyor, lütfen bekleyin.",
        )

    # ✅ production generate
    birthchart_repo.set_status(session=session, reading_id=reading_id, status="processing")

    try:
        result_text = generate_birthchart_reading(
            name=reading.get("name") or "",
            birth_date=reading.get("birth_date") or "",
            birth_time=reading.get("birth_time"),
            birth_city=reading.get("birth_city") or "",
            birth_country=reading.get("birth_country") or "TR",
            topic=reading.get("topic") or "genel",
            question=reading.get("question"),
        )
        if not (result_text or "").strip():
            birthchart_repo.set_status(session=session, reading_id=reading_id, status="paid")
            raise HTTPException(
                status_code=500,
                detail="Doğum haritası yorumu boş döndü. Lütfen tekrar deneyin.",
            )
        updated = birthchart_repo.set_result(session=session, reading_id=reading_id, result_text=result_text.strip())
        try:
            from app.services.fcm_service import send_reading_ready_notification
            send_reading_ready_notification(device_id)
        except Exception:
            pass
        return _mask_result_if_unpaid(updated)

    except HTTPException:
        raise
    except Exception as e:
        birthchart_repo.set_status(session=session, reading_id=reading_id, status="paid")
        raise HTTPException(status_code=500, detail=f"Doğum haritası yorum üretilemedi: {e}")
