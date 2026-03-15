from __future__ import annotations

from datetime import datetime
from uuid import uuid4
import threading
import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session

from app.db import engine, get_session
from app.models.tarot_db import TarotReadingDB
from app.repositories import tarot_repo
from app.schemas.tarot import (
    TarotStartRequest,
    TarotSelectCardsRequest,
    TarotMarkPaidRequest,
    TarotRatingRequest,
    TarotReading,
)
from app.services.openai_service import generate_tarot_reading

router = APIRouter(prefix="/tarot", tags=["tarot"])
log = logging.getLogger("lunaura.tarot")


def _run_generation_in_background(reading_id: str) -> None:
    """
    OpenAI uzun sürebilir, request'i bloklamasın diye thread'de çalışır.
    Hata durumunda 2 kez daha dener; yorum kesin düşsün.
    """
    from sqlmodel import Session as _Session

    max_attempts = 3
    for attempt in range(1, max_attempts + 1):
        with _Session(engine) as session:
            r = tarot_repo.get_reading(session, reading_id)
            if not r:
                return

            if r.status == "completed" and (r.result_text or "").strip():
                return

            if not r.is_paid:
                tarot_repo.set_status(session, reading_id, "paid" if r.payment_ref else "pending_payment")
                return

            if not r.get_cards():
                tarot_repo.set_status(session, reading_id, "paid")
                return

            try:
                cards = r.get_cards()
                text = generate_tarot_reading(
                    name=r.name,
                    age=r.age,
                    topic=r.topic,
                    question=r.question,
                    spread_type=r.spread_type,
                    selected_cards=cards,
                )
                tarot_repo.set_status(session, reading_id, "completed", result_text=text)
                did = (r.device_id or "").strip()
                if did:
                    try:
                        from app.services.fcm_service import send_reading_ready_notification
                        send_reading_ready_notification(did)
                    except Exception:
                        pass
                return
            except Exception:
                log.exception(
                    "Tarot generation attempt %s/%s failed for reading_id=%s",
                    attempt,
                    max_attempts,
                    reading_id,
                )
                if attempt == max_attempts:
                    tarot_repo.set_status(session, reading_id, "paid")
                    return
                # Kısa bekleme sonrası tekrar dene
                import time
                time.sleep(2)


def _spawn_thread(reading_id: str) -> None:
    t = threading.Thread(target=_run_generation_in_background, args=(reading_id,), daemon=True)
    t.start()


def _to_schema(r: TarotReadingDB) -> TarotReading:
    """Ödeme yapılmamışsa yorum (result_text) istemciye gönderilmez."""
    result_text = r.result_text if r.is_paid else None
    return TarotReading(
        id=r.id,
        topic=r.topic,
        question=r.question,
        name=r.name,
        age=r.age,
        spread_type=r.spread_type,
        selected_cards=r.get_cards(),
        status=r.status,
        result_text=result_text,
        rating=getattr(r, "rating", None),
        is_paid=r.is_paid,
        payment_ref=getattr(r, "payment_ref", None),
        created_at=r.created_at,
    )


def _get_or_404(session: Session, reading_id: str) -> TarotReadingDB:
    r = tarot_repo.get_reading(session, reading_id)
    if not r:
        raise HTTPException(status_code=404, detail="Reading not found")
    return r


def _wanted_count(spread_type: str) -> int:
    st = (spread_type or "").strip().lower()
    if st == "three":
        return 3
    if st == "six":
        return 6
    if st == "twelve":
        return 12
    raise HTTPException(status_code=400, detail=f"Geçersiz spread_type: {spread_type}")


@router.post("/start", response_model=TarotReading)
async def start(req: TarotStartRequest, session: Session = Depends(get_session)):
    _wanted_count(req.spread_type)

    obj = TarotReadingDB(
        id=str(uuid4()),
        topic=req.topic,
        question=req.question,
        name=req.name,
        age=req.age,
        spread_type=req.spread_type,
        cards_json="[]",
        status="pending_payment",
        is_paid=False,
        payment_ref=None,
        result_text=None,
        rating=None,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    obj = tarot_repo.create_reading(session, obj)
    return _to_schema(obj)


@router.post("/{reading_id}/select-cards", response_model=TarotReading)
async def select_cards(reading_id: str, req: TarotSelectCardsRequest, session: Session = Depends(get_session)):
    r = _get_or_404(session, reading_id)

    wanted = _wanted_count(r.spread_type)
    if len(req.cards) != wanted:
        raise HTTPException(status_code=400, detail=f"Bu açılım için {wanted} kart seçmelisin.")

    r = tarot_repo.set_cards(session, reading_id, req.cards)
    return _to_schema(r)


@router.post("/{reading_id}/mark-paid", response_model=TarotReading)
async def mark_paid(reading_id: str, body: TarotMarkPaidRequest, session: Session = Depends(get_session)):
    r = _get_or_404(session, reading_id)

    if not body.payment_ref or not body.payment_ref.strip():
        raise HTTPException(status_code=422, detail="payment_ref is required")

    if not r.get_cards():
        raise HTTPException(status_code=400, detail="Ödemeden önce kartlarını seçmelisin.")

    r.is_paid = True
    r.payment_ref = body.payment_ref.strip()
    r.status = "paid"
    r.updated_at = datetime.utcnow()
    r = tarot_repo.update_reading(session, r)
    return _to_schema(r)


@router.post("/{reading_id}/generate", response_model=TarotReading)
async def generate(reading_id: str, session: Session = Depends(get_session)):
    r = _get_or_404(session, reading_id)

    if not r.get_cards():
        raise HTTPException(status_code=400, detail="Önce kart seçmelisin.")
    # Ödeme öncesi generate’e izin ver (yorum DB’de saklanır, _to_schema ödenmemişse göstermez)

    if r.status == "completed" and (r.result_text or "").strip():
        return _to_schema(r)

    # ✅ stale processing kurtarma + atomic lock
    claimed = tarot_repo.claim_processing(session, reading_id, stale_seconds=120)
    if claimed:
        _spawn_thread(reading_id)

    r = _get_or_404(session, reading_id)
    return _to_schema(r)


@router.get("/{reading_id}", response_model=TarotReading)
async def detail(reading_id: str, session: Session = Depends(get_session)):
    r = _get_or_404(session, reading_id)
    return _to_schema(r)


@router.post("/{reading_id}/rate", response_model=TarotReading)
async def rate(reading_id: str, req: TarotRatingRequest, session: Session = Depends(get_session)):
    r = _get_or_404(session, reading_id)

    if req.rating < 1 or req.rating > 5:
        raise HTTPException(status_code=400, detail="Rating must be 1..5")

    r.rating = req.rating
    r.updated_at = datetime.utcnow()
    r = tarot_repo.update_reading(session, r)
    return _to_schema(r)
