# app/api/v1/routes_hand.py
from __future__ import annotations

import os
from typing import List, Optional
from datetime import datetime

from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from pydantic import BaseModel
from sqlmodel import Session, select

from app.db import get_session
from app.core.config import settings
from app.core.device import get_device_id
from app.models.hand_db import HandReadingDB
from app.repositories.hand_repo import (
    get_reading,
    create_reading,
    update_reading,
    set_photos,
    list_photos,
    set_status,
)
from app.services.storage import save_uploads
from app.services.openai_service import generate_hand_fortune, validate_hand_images
from app.schemas.hand import HandStartRequest, HandReading  # sende bu schema zaten var diye varsayıyorum

router = APIRouter(prefix="/hand", tags=["hand"])


class MarkPaidRequest(BaseModel):
    payment_ref: Optional[str] = None


class RatingRequest(BaseModel):
    rating: int


def _ensure_no_blocking_locked_reading(session: Session, device_id: str) -> None:
    stmt = (
        select(HandReadingDB.id)
        .where(
            HandReadingDB.device_id == device_id,
            HandReadingDB.is_paid == False,  # noqa: E712
            HandReadingDB.result_text.is_not(None),
            HandReadingDB.result_text != "",
        )
        .order_by(HandReadingDB.created_at.desc())
        .limit(1)
    )
    existing_id = session.exec(stmt).first()
    if existing_id:
        raise HTTPException(
            status_code=409,
            detail="Bu bölümde kilidi açılmamış hazır bir yorumunuz var. Yeni yorumdan önce mevcut yorumu açın.",
        )


def _get_or_404_owner(session: Session, reading_id: str, device_id: str) -> HandReadingDB:
    r = get_reading(session, reading_id)
    if not r:
        raise HTTPException(status_code=404, detail="Reading not found")

    rid = (getattr(r, "device_id", None) or "").strip()

    # farklı cihaz -> 404
    if rid and rid != device_id:
        raise HTTPException(status_code=404, detail="Reading not found")

    # legacy -> bağla
    if not rid:
        try:
            r.device_id = device_id
            r.updated_at = datetime.utcnow()
            update_reading(session, r)
        except Exception:
            pass

    return r


def _to_schema(r: HandReadingDB) -> HandReading:
    """Ödeme yapılmamışsa yorum (result_text/comment) istemciye gönderilmez."""
    photos = list_photos(r)
    has_result = bool((r.result_text or "").strip())
    result = (r.result_text if r.is_paid else None)

    return HandReading(
        id=r.id,
        topic=r.topic,
        question=r.question,
        name=r.name,
        age=r.age,
        photos=photos,
        status=r.status,
        has_result=has_result,
        comment=result,
        result_text=result,
        rating=r.rating,
        is_paid=r.is_paid,
        payment_ref=r.payment_ref,
        created_at=r.created_at,
    )


def _delete_paths(paths: List[str]) -> None:
    for p in paths:
        try:
            if os.path.exists(p):
                os.remove(p)
        except Exception:
            pass


@router.post("/start", response_model=HandReading)
async def start(
    req: HandStartRequest,
    session: Session = Depends(get_session),
    device_id: str = Depends(get_device_id),
):
    """
    Akış:
      1) /hand/start -> reading_id (pending_payment)
      2) /hand/{id}/upload-images -> foto yükle (photos_uploaded)
      3) ödeme -> /payments/intent + /payments/verify (paid)
      4) /hand/{id}/generate -> yorum üret (processing -> completed)
    """
    _ensure_no_blocking_locked_reading(session, device_id)

    db_obj = HandReadingDB(
        topic=req.topic,
        question=req.question,
        name=req.name,
        age=req.age,
        status="pending_payment",
        is_paid=False,
        payment_ref=None,
        result_text=None,
        images_json="[]",
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
        device_id=device_id,
    )

    db_obj = create_reading(session, db_obj)
    return _to_schema(db_obj)


@router.post("/{reading_id}/upload", response_model=HandReading)
@router.post("/{reading_id}/upload-images", response_model=HandReading)
async def upload_images(
    reading_id: str,
    files: List[UploadFile] = File(...),
    session: Session = Depends(get_session),
    device_id: str = Depends(get_device_id),
):
    _get_or_404_owner(session, reading_id, device_id)

    if len(files) < settings.min_photos or len(files) > settings.max_photos:
        raise HTTPException(
            status_code=400,
            detail=f"Foto sayısı {settings.min_photos}-{settings.max_photos} aralığında olmalı.",
        )

    saved = await save_uploads(reading_id, files)

    verdict = validate_hand_images(saved)
    if not verdict.get("ok", False):
        _delete_paths(saved)
        reason = (verdict.get("reason") or "").strip()
        msg = "Lütfen yalnızca avuç içi (palm) fotoğrafı yükleyiniz."
        if reason:
            msg = f"{msg} ({reason})"
        raise HTTPException(status_code=400, detail=msg)

    r2 = set_photos(session, reading_id, saved)
    return _to_schema(r2)


@router.post("/{reading_id}/mark-paid", response_model=HandReading)
async def mark_paid(
    reading_id: str,
    body: MarkPaidRequest,
    session: Session = Depends(get_session),
    device_id: str = Depends(get_device_id),
):
    """
    ✅ Legacy/mock akış (TEST-...).
    Real ödeme: /payments/verify.
    """
    r = _get_or_404_owner(session, reading_id, device_id)

    if not list_photos(r):
        raise HTTPException(status_code=400, detail="Ödeme için önce fotoğraf yüklemelisin.")

    if not body.payment_ref:
        raise HTTPException(status_code=422, detail="payment_ref is required")

    if not str(body.payment_ref).startswith("TEST-"):
        raise HTTPException(
            status_code=403,
            detail="mark-paid is legacy only. Use /payments/verify for real payments.",
        )

    if r.is_paid and r.payment_ref:
        return _to_schema(r)

    r.is_paid = True
    r.payment_ref = body.payment_ref
    r.status = "paid"
    r.updated_at = datetime.utcnow()
    r = update_reading(session, r)
    return _to_schema(r)


@router.post("/{reading_id}/generate", response_model=HandReading)
async def generate(
    reading_id: str,
    session: Session = Depends(get_session),
    device_id: str = Depends(get_device_id),
):
    r = _get_or_404_owner(session, reading_id, device_id)

    photos = list_photos(r)
    if not photos:
        raise HTTPException(status_code=400, detail="No photos uploaded")

    # Ödeme öncesi generate’e izin ver (yorum DB’de saklanır, _to_schema ödenmemişse göstermez)
    status = (r.status or "").lower().strip()
    result_text = (r.result_text or "").strip()

    if result_text:
        return _to_schema(r)

    if status == "processing":
        return _to_schema(r)

    verdict = validate_hand_images(photos)
    if not verdict.get("ok", False):
        reason = (verdict.get("reason") or "").strip()
        msg = "Lütfen yalnızca avuç içi (palm) fotoğrafı yükleyiniz."
        if reason:
            msg = f"{msg} ({reason})"
        raise HTTPException(status_code=400, detail=msg)

    set_status(session, reading_id, "processing")

    try:
        comment = generate_hand_fortune(
            name=r.name,
            topic=r.topic,
            question=r.question,
            image_paths=photos,
        )
        comment = (comment or "").strip()

        if not comment:
            set_status(session, reading_id, "paid", comment=None)
            raise HTTPException(status_code=500, detail="Yorum üretilemedi (boş sonuç).")

        r2 = set_status(session, reading_id, "completed", comment=comment)
        try:
            from app.services.fcm_service import send_reading_ready_notification
            send_reading_ready_notification(device_id)
        except Exception:
            pass
        return _to_schema(r2)

    except HTTPException:
        raise
    except Exception as e:
        try:
            set_status(session, reading_id, "paid", comment=None)
        except Exception:
            pass
        raise HTTPException(status_code=500, detail=f"El falı yorum üretilemedi: {e}")


@router.get("/{reading_id}", response_model=HandReading)
async def detail(
    reading_id: str,
    session: Session = Depends(get_session),
    device_id: str = Depends(get_device_id),
):
    r = _get_or_404_owner(session, reading_id, device_id)
    return _to_schema(r)


@router.post("/{reading_id}/rate", response_model=HandReading)
async def rate(
    reading_id: str,
    req: RatingRequest,
    session: Session = Depends(get_session),
    device_id: str = Depends(get_device_id),
):
    r = _get_or_404_owner(session, reading_id, device_id)
    if req.rating < 1 or req.rating > 5:
        raise HTTPException(status_code=400, detail="Rating must be 1..5")
    r.rating = req.rating
    r.updated_at = datetime.utcnow()
    r = update_reading(session, r)
    return _to_schema(r)
