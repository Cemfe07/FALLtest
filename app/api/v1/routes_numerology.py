# app/api/v1/routes_numerology.py
from __future__ import annotations

from typing import Any, Dict

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from app.core.device import get_device_id
from app.db import get_session
from app.models.numerology_db import NumerologyReadingDB
from app.schemas.numerology import NumerologyStartIn, NumerologyReadingOut, MarkPaidIn
from app.repositories.numerology_repo import NumerologyRepo
from app.services.openai_service import generate_numerology_reading

router = APIRouter(prefix="/numerology", tags=["numerology"])
_repo = NumerologyRepo()


def _ensure_no_blocking_locked_reading(session: Session, device_id: str) -> None:
    stmt = (
        select(NumerologyReadingDB.id)
        .where(
            NumerologyReadingDB.device_id == device_id,
            NumerologyReadingDB.is_paid == False,  # noqa: E712
            NumerologyReadingDB.result_text.is_not(None),
            NumerologyReadingDB.result_text != "",
        )
        .order_by(NumerologyReadingDB.created_at.desc())
        .limit(1)
    )
    existing_id = session.exec(stmt).first()
    if existing_id:
        raise HTTPException(
            status_code=409,
            detail="Bu bölümde kilidi açılmamış hazır bir yorumunuz var. Yeni yorumdan önce mevcut yorumu açın.",
        )


def _as_dict(obj: Any) -> Dict[str, Any]:
    """
    Repo bazen dict, bazen Pydantic/SQLModel döndürebilir.
    Bu helper tümünü dict'e normalize eder.
    """
    if obj is None:
        return {}
    if isinstance(obj, dict):
        return obj
    # pydantic v2
    if hasattr(obj, "model_dump"):
        return obj.model_dump()
    # pydantic v1
    if hasattr(obj, "dict"):
        return obj.dict()

    d = {}
    for k in [
        "id",
        "topic",
        "question",
        "name",
        "birth_date",
        "status",
        "result_text",
        "rating",
        "is_paid",
        "payment_ref",
        "created_at",
        "updated_at",
        "device_id",
    ]:
        if hasattr(obj, k):
            d[k] = getattr(obj, k)
    return d


def _require_owner(obj: Any, device_id: str) -> Dict[str, Any]:
    d = _as_dict(obj)
    stored = (d.get("device_id") or "").strip()
    if stored and stored != device_id:
        raise HTTPException(status_code=404, detail="Numerology kaydı bulunamadı.")
    return d


def _mask_result_if_unpaid(obj: Any) -> Dict[str, Any]:
    """Ödeme yapılmamışsa result_text istemciye gönderilmez."""
    d = _as_dict(obj)
    d["has_result"] = bool((d.get("result_text") or "").strip())
    if not d.get("is_paid"):
        d["result_text"] = None
    return d


@router.post("/start", response_model=NumerologyReadingOut)
def start(
    payload: NumerologyStartIn,
    session: Session = Depends(get_session),
    device_id: str = Depends(get_device_id),
):
    """
    Numerology akışı:
      1) /numerology/start -> reading_id (pending_payment/started)
      2) ödeme -> /payments/intent + /payments/verify (paid)
      3) /numerology/{id}/generate -> yorum üret (processing -> completed)
    """
    try:
        _ensure_no_blocking_locked_reading(session, device_id)
        created = _repo.create(
            session=session,
            name=payload.name,
            birth_date=payload.birth_date,
            topic=payload.topic,
            question=payload.question,
            device_id=device_id,
        )
        if not created:
            raise HTTPException(status_code=500, detail="Numerology kayıt oluşturulamadı.")
        _require_owner(created, device_id)
        return created
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Numerology start failed: {e}")


@router.get("/{reading_id}", response_model=NumerologyReadingOut)
def get_reading(
    reading_id: str,
    session: Session = Depends(get_session),
    device_id: str = Depends(get_device_id),
):
    obj = _repo.get(session=session, reading_id=reading_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Numerology kaydı bulunamadı.")
    _require_owner(obj, device_id)
    return _mask_result_if_unpaid(obj)


@router.post("/{reading_id}/mark-paid", response_model=NumerologyReadingOut)
def mark_paid(
    reading_id: str,
    payload: MarkPaidIn,
    session: Session = Depends(get_session),
    device_id: str = Depends(get_device_id),
):
    """
    ✅ Legacy/mock akış bozulmasın diye endpoint duruyor.
    🔒 Sadece TEST-... (mock) ödeme ref ile çalışır.
    Real ödeme: /payments/verify server-side unlock/mark_paid yapar.
    """
    if not payload.payment_ref:
        raise HTTPException(status_code=422, detail="payment_ref is required")

    if not str(payload.payment_ref).startswith("TEST-"):
        raise HTTPException(
            status_code=403,
            detail="mark-paid is legacy only. Use /payments/verify for real payments.",
        )

    obj0 = _repo.get(session=session, reading_id=reading_id)
    if not obj0:
        raise HTTPException(status_code=404, detail="Numerology kaydı bulunamadı (mark-paid).")
    _require_owner(obj0, device_id)

    obj = _repo.mark_paid(session=session, reading_id=reading_id, payment_ref=payload.payment_ref)
    if not obj:
        raise HTTPException(status_code=404, detail="Numerology kaydı bulunamadı (mark-paid).")
    return _mask_result_if_unpaid(obj)


@router.post("/{reading_id}/generate", response_model=NumerologyReadingOut)
def generate(
    reading_id: str,
    session: Session = Depends(get_session),
    device_id: str = Depends(get_device_id),
):
    obj = _repo.get(session=session, reading_id=reading_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Numerology kaydı bulunamadı (generate).")

    d = _require_owner(obj, device_id)

    # Ödeme öncesi generate’e izin ver (yorum DB’de saklanır, _mask_result_if_unpaid ödenmemişse göstermez)
    status = (d.get("status") or "").lower().strip()
    result_text = (d.get("result_text") or "").strip()

    if result_text:
        return _mask_result_if_unpaid(obj)

    if status == "processing":
        return _mask_result_if_unpaid(obj)

    if status not in ("paid", "processing", "completed"):
        _repo.set_status(session=session, reading_id=reading_id, status="paid")
        obj = _repo.get(session=session, reading_id=reading_id) or obj
        d = _as_dict(obj)
        status = (d.get("status") or "").lower().strip()

    _repo.set_status(session=session, reading_id=reading_id, status="processing")

    try:
        text = generate_numerology_reading(
            name=d.get("name", ""),
            birth_date=d.get("birth_date", ""),
            topic=d.get("topic", "genel"),
            question=d.get("question"),
        )
        text = (text or "").strip()
        if not text:
            _repo.set_status(session=session, reading_id=reading_id, status="paid")
            raise HTTPException(status_code=500, detail="Yorum üretilemedi (boş sonuç).")

        updated = _repo.set_result(session=session, reading_id=reading_id, result_text=text)
        if not updated:
            _repo.set_status(session=session, reading_id=reading_id, status="paid")
            raise HTTPException(status_code=500, detail="AI sonucu DB'ye yazılamadı.")

        try:
            _repo.set_status(session=session, reading_id=reading_id, status="completed")
        except Exception:
            pass

        try:
            from app.services.fcm_service import send_reading_ready_notification
            send_reading_ready_notification(device_id)
        except Exception:
            pass

        return _mask_result_if_unpaid(updated)

    except HTTPException:
        _repo.set_status(session=session, reading_id=reading_id, status="paid")
        raise
    except Exception as e:
        _repo.set_status(session=session, reading_id=reading_id, status="paid")
        raise HTTPException(status_code=500, detail=f"Numerology yorum üretilemedi: {e}")
