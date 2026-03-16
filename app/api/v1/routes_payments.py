# app/api/v1/routes_payments.py
from __future__ import annotations

from datetime import datetime
from uuid import uuid4
from typing import Optional, Literal

from fastapi import APIRouter, HTTPException, Depends, Header
from pydantic import BaseModel, Field as PField
from sqlmodel import Session

from app.db import get_session
from app.schemas.payments import StartPaymentRequest, StartPaymentResponse
from app.core.products import get_sku_info
from app.services.iap_verify_service import verify_google_play, verify_app_store

from app.repositories.payment_repo import payment_repo

# repos (mevcut yapına göre)
from app.repositories import tarot_repo
from app.repositories.hand_repo import (
    get_reading as hand_get_reading,
    list_photos as hand_list_photos,
    update_reading as hand_update_reading,
)
from app.repositories.coffee_repo import (
    get_reading as coffee_get_reading,
    list_photos as coffee_list_photos,
    update_reading as coffee_update_reading,
)
from app.repositories.numerology_repo import NumerologyRepo
from app.repositories.birthchart_repo import birthchart_repo
from app.repositories.personality_repo import personality_repo
from app.repositories.synastry_repo import synastry_repo


router = APIRouter(prefix="/payments", tags=["payments"])

# ============================================================
# ✅ LEGACY start endpoint’i (bozulmasın)
# ============================================================

TAROT_ALLOWED_AMOUNTS = {149.0, 199.0, 250.0}
HAND_AMOUNT = 39.0
COFFEE_AMOUNT = 49.0


@router.post("/start", response_model=StartPaymentResponse)
async def start_payment(req: StartPaymentRequest):
    """
    Legacy / mock start:
    Flutter'da bazı eski akışlar bunu kullanabiliyor (debug/local).
    Store verify değildir.
    """
    if req.product == "coffee" and req.amount is None:
        raise HTTPException(status_code=422, detail="amount is required for coffee")

    if req.product == "hand":
        amount = HAND_AMOUNT

    elif req.product == "tarot":
        if req.amount is None:
            raise HTTPException(status_code=422, detail="amount is required for tarot")
        amt = round(float(req.amount), 1)
        if amt not in TAROT_ALLOWED_AMOUNTS:
            raise HTTPException(
                status_code=422,
                detail=f"invalid tarot amount: {amt}. allowed: {sorted(TAROT_ALLOWED_AMOUNTS)}",
            )
        amount = amt

    elif req.product == "coffee":
        amount = float(req.amount or COFFEE_AMOUNT)

    else:
        # diğer ürünler için legacy mock'ta amount zorunlu değil
        amount = float(req.amount or 0.0)

    payment_id = f"TEST-{uuid4().hex}"

    return StartPaymentResponse(
        ok=True,
        status="success",
        provider="mock",
        product=req.product,
        reading_id=req.reading_id,
        amount=amount,
        payment_id=payment_id,
        payment_ref=payment_id,
    )


# ============================================================
# ✅ NEW Store/IAP endpoints (Flutter PurchaseApi ile uyumlu)
# ============================================================

def _require_device_id(x_device_id: Optional[str]) -> str:
    if not x_device_id or len(x_device_id.strip()) < 8:
        raise HTTPException(status_code=400, detail="X-Device-Id header is required")
    return x_device_id.strip()


class PaymentIntentRequest(BaseModel):
    reading_id: str = PField(..., min_length=3)
    sku: str = PField(..., min_length=3)


class PaymentIntentResponse(BaseModel):
    ok: bool = True
    status: Literal["pending"] = "pending"
    payment_id: str
    reading_id: str
    sku: str
    product: str
    amount: float
    currency: str = "TRY"


class PaymentVerifyRequest(BaseModel):
    payment_id: str = PField(..., min_length=6)
    platform: Literal["google_play", "app_store"]
    sku: str = PField(..., min_length=3)
    transaction_id: str = PField(..., min_length=3)
    purchase_token: Optional[str] = None
    receipt_data: Optional[str] = None


class PaymentVerifyResponse(BaseModel):
    ok: bool = True
    verified: bool
    payment_id: str
    status: str


def _check_prerequisites(*, session: Session, product: str, reading_id: str) -> None:
    """
    ✅ En kritik fix:
    Store doğrulamasına geçmeden ÖNCE ürünün gerektirdiği adımlar tamam mı kontrol eder.
    Yanlış sırada gelinirse 409 dönerek kullanıcıyı doğru adıma yönlendirir.
    Böylece “para çekildi ama akış ilerlemedi” vakaları biter.
    """
    # TAROT -> kart seçimi şart
    if product == "tarot":
        r = tarot_repo.get_reading(session, reading_id)
        if not r:
            raise HTTPException(status_code=404, detail="Tarot reading not found for this payment")
        if not r.get_cards():
            raise HTTPException(status_code=409, detail="Cards must be selected before payment")
        if not (r.result_text or "").strip():
            raise HTTPException(status_code=409, detail="Tarot reading is still preparing. Please wait for it to be ready.")
        return

    # HAND -> foto şart
    if product == "hand":
        r = hand_get_reading(session, reading_id)
        if not r:
            raise HTTPException(status_code=404, detail="Hand reading not found for this payment")
        if not hand_list_photos(r):
            raise HTTPException(status_code=409, detail="Upload hand photos before payment")
        return

    # COFFEE -> foto şart
    if product == "coffee":
        r = coffee_get_reading(session, reading_id)
        if not r:
            raise HTTPException(status_code=404, detail="Coffee reading not found for this payment")
        if not coffee_list_photos(r):
            raise HTTPException(status_code=409, detail="Upload coffee photos before payment")
        return

    # PERSONALITY -> yorum hazır olmalı
    if product == "personality":
        reading = personality_repo.get(session=session, reading_id=reading_id)
        if not reading:
            raise HTTPException(status_code=404, detail="Personality reading not found for this payment")
        if not (reading.get("result_text") or "").strip():
            raise HTTPException(status_code=409, detail="Personality reading is still preparing. Please wait for it to be ready.")
        return

    # SYNASTRY -> yorum hazır olmalı
    if product == "synastry":
        reading = synastry_repo.get(session=session, reading_id=reading_id)
        if not reading:
            raise HTTPException(status_code=404, detail="Synastry reading not found for this payment")
        if not (reading.get("result_text") or "").strip():
            raise HTTPException(status_code=409, detail="Synastry reading is still preparing. Please wait for it to be ready.")
        return

    # NUMEROLOGY / BIRTHCHART -> precondition yok
    return


def _unlock_reading_for_product(
    *,
    session: Session,
    product: str,
    reading_id: str,
    payment_ref: str,
) -> None:
    """
    ✅ CRITICAL: unlock işlemi idempotent olmalı.
    Yani tekrar çağrılırsa zarar vermemeli.
    """

    # -------------------------
    # TAROT (kart seçimi şart)
    # -------------------------
    if product == "tarot":
        r = tarot_repo.get_reading(session, reading_id)
        if not r:
            raise HTTPException(status_code=404, detail="Tarot reading not found for this payment")
        if not r.get_cards():
            raise HTTPException(status_code=400, detail="Cards must be selected before verifying payment")

        # idempotent unlock
        r.is_paid = True
        r.payment_ref = payment_ref
        r.status = "paid"
        r.updated_at = datetime.utcnow()
        tarot_repo.update_reading(session, r)
        return

    # -------------------------
    # HAND (foto şart)
    # -------------------------
    if product == "hand":
        r = hand_get_reading(session, reading_id)
        if not r:
            raise HTTPException(status_code=404, detail="Hand reading not found for this payment")
        photos = hand_list_photos(r)
        if not photos:
            raise HTTPException(status_code=400, detail="Photos must be uploaded before verifying payment")

        # idempotent unlock
        r.is_paid = True
        r.payment_ref = payment_ref
        r.status = "paid"
        r.updated_at = datetime.utcnow()
        hand_update_reading(session, r)
        return

    # -------------------------
    # COFFEE (foto şart)
    # -------------------------
    if product == "coffee":
        r = coffee_get_reading(session, reading_id)
        if not r:
            raise HTTPException(status_code=404, detail="Coffee reading not found for this payment")
        photos = coffee_list_photos(r)
        if not photos:
            raise HTTPException(status_code=400, detail="Photos must be uploaded before verifying payment")

        # idempotent unlock
        r.is_paid = True
        r.payment_ref = payment_ref
        r.status = "paid"
        r.updated_at = datetime.utcnow()
        coffee_update_reading(session, r)
        return

    # -------------------------
    # NUMEROLOGY
    # -------------------------
    if product == "numerology":
        nrepo = NumerologyRepo()
        obj = nrepo.get(session=session, reading_id=reading_id)
        if not obj:
            raise HTTPException(status_code=404, detail="Numerology reading not found for this payment")
        if not nrepo.mark_paid(session=session, reading_id=reading_id, payment_ref=payment_ref):
            raise HTTPException(status_code=500, detail="Numerology mark_paid failed")
        return

    # -------------------------
    # BIRTHCHART
    # -------------------------
    if product == "birthchart":
        reading = birthchart_repo.get(session=session, reading_id=reading_id)
        if not reading:
            raise HTTPException(status_code=404, detail="Birthchart reading not found for this payment")
        if not birthchart_repo.mark_paid(session=session, reading_id=reading_id, payment_ref=payment_ref):
            raise HTTPException(status_code=500, detail="Birthchart mark_paid failed")
        return

    # -------------------------
    # PERSONALITY
    # -------------------------
    if product == "personality":
        reading = personality_repo.get(session=session, reading_id=reading_id)
        if not reading:
            raise HTTPException(status_code=404, detail="Personality reading not found for this payment")
        if not personality_repo.mark_paid(session=session, reading_id=reading_id, payment_ref=payment_ref):
            raise HTTPException(status_code=500, detail="Personality mark_paid failed")
        return

    # -------------------------
    # SYNASTRY
    # -------------------------
    if product == "synastry":
        reading = synastry_repo.get(session=session, reading_id=reading_id)
        if not reading:
            raise HTTPException(status_code=404, detail="Synastry reading not found for this payment")
        if not synastry_repo.mark_paid(session=session, reading_id=reading_id, payment_ref=payment_ref):
            raise HTTPException(status_code=500, detail="Synastry mark_paid failed")
        return

    raise HTTPException(status_code=422, detail=f"Unsupported product: {product}")


@router.post("/intent", response_model=PaymentIntentResponse)
async def create_intent(
    req: PaymentIntentRequest,
    session: Session = Depends(get_session),
    x_device_id: Optional[str] = Header(default=None, alias="X-Device-Id"),
):
    device_id = _require_device_id(x_device_id)

    sku_info = get_sku_info(req.sku)
    if not sku_info:
        raise HTTPException(status_code=422, detail=f"Unknown sku: {req.sku}")

    payment = payment_repo.create_intent(
        session=session,
        device_id=device_id,
        reading_id=req.reading_id,
        sku=req.sku,
    )

    return PaymentIntentResponse(
        ok=True,
        status="pending",
        payment_id=payment.id,
        reading_id=payment.reading_id,
        sku=payment.sku,
        product=payment.product,
        amount=float(payment.amount),
        currency=payment.currency,
    )


@router.post("/verify", response_model=PaymentVerifyResponse)
async def verify_payment(
    req: PaymentVerifyRequest,
    session: Session = Depends(get_session),
    x_device_id: Optional[str] = Header(default=None, alias="X-Device-Id"),
):
    device_id = _require_device_id(x_device_id)

    sku_info = get_sku_info(req.sku)
    if not sku_info:
        raise HTTPException(status_code=422, detail=f"Unknown sku: {req.sku}")

    payment = payment_repo.get(session=session, payment_id=req.payment_id)
    if not payment:
        raise HTTPException(status_code=404, detail="payment not found")

    if payment.device_id != device_id:
        raise HTTPException(status_code=403, detail="payment device mismatch")

    if payment.sku != req.sku:
        raise HTTPException(status_code=422, detail="sku mismatch for this payment")

    if payment.product != sku_info.product:
        raise HTTPException(status_code=422, detail="product mismatch for this payment")

    # platform payload zorunlulukları
    if req.platform == "google_play":
        if not (req.purchase_token or "").strip():
            raise HTTPException(status_code=422, detail="purchase_token is required for google_play")
    else:
        if not (req.receipt_data or "").strip():
            raise HTTPException(status_code=422, detail="receipt_data is required for app_store")

    # ✅ PRECONDITION CHECK (store verify’den ÖNCE)
    # FIX-1: sku_info.product yerine payment.product ile kontrol
    _check_prerequisites(session=session, product=payment.product, reading_id=payment.reading_id)

    # ✅ verified ise idempotent davran (ve unlock hata verse bile verify'yi fail etme)
    if payment.status == "verified":
        if payment.transaction_id and payment.transaction_id != req.transaction_id:
            raise HTTPException(
                status_code=409,
                detail="payment already verified with different transaction_id",
            )

        # 🔥 KRİTİK: verified olsa bile reading unlock değilse tekrar dene
        # FIX-2: HTTPException değil, genel Exception yakala
        try:
            _unlock_reading_for_product(
                session=session,
                product=payment.product,
                reading_id=payment.reading_id,
                payment_ref=payment.id,
            )
        except Exception:
            # unlock başarısız olsa bile verify'yi bozma (idempotent)
            pass

        return PaymentVerifyResponse(ok=True, verified=True, payment_id=payment.id, status="verified")

    # ------------------------------------------------------------
    # 1) Store doğrulama (stub veya gerçek)
    # ------------------------------------------------------------
    if req.platform == "google_play":
        res = verify_google_play(
            purchase_token=(req.purchase_token or ""),
            sku=req.sku,
            transaction_id=req.transaction_id,
        )
    else:
        res = verify_app_store(
            receipt_data=(req.receipt_data or ""),
            sku=req.sku,
            transaction_id=req.transaction_id,
        )

    if not res.ok:
        raise HTTPException(status_code=402, detail=f"IAP verification failed: {res.message}")

    # ------------------------------------------------------------
    # 2) PaymentDB verified yap
    # ------------------------------------------------------------
    payment = payment_repo.mark_verified(
        session=session,
        payment=payment,
        platform=req.platform,
        transaction_id=req.transaction_id,
        purchase_token=req.purchase_token,
        receipt_data=req.receipt_data,
    )

    # ------------------------------------------------------------
    # 3) İlgili reading’i unlock et (mark_paid)
    # ------------------------------------------------------------
    _unlock_reading_for_product(
        session=session,
        product=payment.product,
        reading_id=payment.reading_id,
        payment_ref=payment.id,
    )

    return PaymentVerifyResponse(ok=True, verified=True, payment_id=payment.id, status="verified")
