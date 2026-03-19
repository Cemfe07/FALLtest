from __future__ import annotations

from uuid import uuid4
from typing import Any, Dict
from fastapi import APIRouter, HTTPException, Depends
from fastapi.responses import Response
from sqlmodel import Session, select

from app.db import get_session
from app.core.device import get_device_id
from app.models.synastry_db import SynastryReadingDB
from app.schemas.synastry import SynastryStartRequest, SynastryMarkPaidRequest, SynastryRatingRequest
from app.repositories.synastry_repo import synastry_repo

from app.services.synastry_service import generate_synastry_reading
from app.services.pdf_service import build_synastry_pdf_bytes


router = APIRouter(prefix="/synastry", tags=["synastry"])


def _ensure_no_blocking_locked_reading(session: Session, device_id: str) -> None:
    stmt = (
        select(SynastryReadingDB.id)
        .where(
            SynastryReadingDB.device_id == device_id,
            SynastryReadingDB.is_paid == False,  # noqa: E712
            SynastryReadingDB.result_text.is_not(None),
            SynastryReadingDB.result_text != "",
        )
        .order_by(SynastryReadingDB.created_at.desc())
        .limit(1)
    )
    existing_id = session.exec(stmt).first()
    if existing_id:
        raise HTTPException(
            status_code=409,
            detail="Bu bölümde kilidi açılmamış hazır bir yorumunuz var. Yeni yorumdan önce mevcut yorumu açın.",
        )


def _mask_result_if_unpaid(reading: Dict[str, Any]) -> Dict[str, Any]:
    """Ödeme yapılmamışsa result_text istemciye gönderilmez."""
    if not reading:
        return reading
    out = dict(reading)
    out["has_result"] = bool((out.get("result_text") or "").strip())
    if not out.get("is_paid"):
        out["result_text"] = None
    return out


@router.post("/start")
def start(
    payload: SynastryStartRequest,
    session: Session = Depends(get_session),
    device_id: str = Depends(get_device_id),
):
    _ensure_no_blocking_locked_reading(session, device_id)

    try:
        reading = synastry_repo.create(
            session=session,
            device_id=device_id,
            name_a=payload.name_a,
            birth_date_a=payload.birth_date_a,
            birth_time_a=payload.birth_time_a,
            birth_city_a=payload.birth_city_a,
            birth_country_a=payload.birth_country_a,
            name_b=payload.name_b,
            birth_date_b=payload.birth_date_b,
            birth_time_b=payload.birth_time_b,
            birth_city_b=payload.birth_city_b,
            birth_country_b=payload.birth_country_b,
            topic=payload.topic,
            question=payload.question,
        )
        return reading
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Synastry start failed: {e}")


@router.get("/{reading_id}")
def get_status(reading_id: str, session: Session = Depends(get_session)):
    reading = synastry_repo.get(session=session, reading_id=reading_id)
    if not reading:
        raise HTTPException(status_code=404, detail="Reading not found")
    return _mask_result_if_unpaid(reading)


@router.post("/{reading_id}/mark-paid")
def mark_paid(
    reading_id: str,
    payload: SynastryMarkPaidRequest | None = None,
    session: Session = Depends(get_session),
):
    payment_ref = (payload.payment_ref if payload else None)

    if not payment_ref:
        raise HTTPException(status_code=422, detail="payment_ref is required")

    if not str(payment_ref).startswith("TEST-"):
        raise HTTPException(
            status_code=403,
            detail="mark-paid is legacy only. Use /payments/verify for real payments.",
        )

    reading = synastry_repo.mark_paid(session=session, reading_id=reading_id, payment_ref=payment_ref)
    if not reading:
        raise HTTPException(status_code=404, detail="Reading not found")
    return _mask_result_if_unpaid(reading)


@router.post("/{reading_id}/generate")
def generate(reading_id: str, session: Session = Depends(get_session)):
    reading, claimed = synastry_repo.claim_processing(session=session, reading_id=reading_id)
    if not reading:
        raise HTTPException(status_code=404, detail="Reading not found")

    # Ödeme öncesi generate'e izin ver (yorum DB'de saklanır, _mask_result_if_unpaid ödenmemişse göstermez)
    if (reading.get("result_text") or "").strip():
        return _mask_result_if_unpaid(reading)

    if (reading.get("status") or "").lower().strip() == "processing" and not claimed:
        return _mask_result_if_unpaid(reading)

    try:
        result_text = generate_synastry_reading(
            name_a=reading.get("name_a") or "",
            birth_date_a=reading.get("birth_date_a") or "",
            birth_time_a=reading.get("birth_time_a"),
            birth_city_a=reading.get("birth_city_a") or "",
            birth_country_a=reading.get("birth_country_a") or "TR",
            name_b=reading.get("name_b") or "",
            birth_date_b=reading.get("birth_date_b") or "",
            birth_time_b=reading.get("birth_time_b"),
            birth_city_b=reading.get("birth_city_b") or "",
            birth_country_b=reading.get("birth_country_b") or "TR",
            topic=reading.get("topic") or "Genel",
            question=reading.get("question"),
        )
        updated = synastry_repo.set_result(session=session, reading_id=reading_id, result_text=result_text)
        did = (reading.get("device_id") or "").strip()
        if did:
            try:
                from app.services.fcm_service import send_reading_ready_notification
                send_reading_ready_notification(did)
            except Exception:
                pass
        return _mask_result_if_unpaid(updated)
    except Exception as e:
        fallback_status = "paid" if reading.get("is_paid") else "started"
        synastry_repo.set_status(session=session, reading_id=reading_id, status=fallback_status)
        raise HTTPException(status_code=500, detail=f"Synastry üretilemedi: {e}")


@router.post("/{reading_id}/rate")
def rate(reading_id: str, payload: SynastryRatingRequest, session: Session = Depends(get_session)):
    reading = synastry_repo.set_rating(session=session, reading_id=reading_id, rating=payload.rating)
    if not reading:
        raise HTTPException(status_code=404, detail="Reading not found")
    return reading


@router.get("/{reading_id}/pdf")
def download_pdf(reading_id: str, session: Session = Depends(get_session)):
    reading = synastry_repo.get(session=session, reading_id=reading_id)
    if not reading:
        raise HTTPException(status_code=404, detail="Reading not found")

    if not (reading.get("result_text") or "").strip():
        raise HTTPException(status_code=409, detail="Result not generated yet")

    pdf_bytes = build_synastry_pdf_bytes(
        title="Sinastri (Aşk Uyumu) Analizi",
        reading=reading,
    )

    filename = f"synastry_{reading_id}.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
