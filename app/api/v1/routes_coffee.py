from __future__ import annotations

import os
from typing import List
from datetime import datetime

from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from pydantic import BaseModel
from sqlmodel import Session

from app.db import get_session
from app.core.config import settings
from app.core.device import get_device_id
from app.models.coffee_db import CoffeeReadingDB
from app.repositories.coffee_repo import (
    get_reading,
    create_reading,
    update_reading,
    set_photos,
    list_photos,
    set_status,
)
from app.services.storage import save_uploads
from app.services.openai_service import (
    generate_fortune,
    validate_coffee_images,
    AIInsufficientQuotaError,
    AIServiceUnavailableError,
    AIServiceError,
)

from app.schemas.coffee import CoffeeStartRequest, CoffeeReading

router = APIRouter(prefix="/coffee", tags=["coffee"])


class RatingRequest(BaseModel):
    rating: int


def _get_or_404_owner(
    session: Session, reading_id: str, device_id: str
) -> CoffeeReadingDB:
    r = get_reading(session, reading_id)
    if not r:
        raise HTTPException(status_code=404, detail="Reading not found")

    rid = (r.device_id or "").strip()
    if rid and rid != device_id:
        raise HTTPException(status_code=404, detail="Reading not found")

    if not rid:
        r.device_id = device_id
        r.updated_at = datetime.utcnow()
        update_reading(session, r)

    return r


def _to_schema(r: CoffeeReadingDB) -> CoffeeReading:
    """Ödeme yapılmamışsa yorum (result_text/comment) istemciye gönderilmez."""
    photos = list_photos(r)
    has_result = bool((r.result_text or "").strip())
    result = r.result_text if r.is_paid else None

    return CoffeeReading(
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


# --------------------------------------------------
# START
# --------------------------------------------------
@router.post("/start", response_model=CoffeeReading)
async def start(
    req: CoffeeStartRequest,
    session: Session = Depends(get_session),
    device_id: str = Depends(get_device_id),
):
    db_obj = CoffeeReadingDB(
        topic=req.topic,
        question=req.question,
        name=req.name,
        age=req.age,
        status="pending_payment",
        is_paid=False,
        images_json="[]",
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
        device_id=device_id,
    )

    db_obj = create_reading(session, db_obj)
    return _to_schema(db_obj)


# --------------------------------------------------
# UPLOAD IMAGES
# --------------------------------------------------
@router.post("/{reading_id}/upload-images", response_model=CoffeeReading)
async def upload_images(
    reading_id: str,
    files: List[UploadFile] = File(...),
    session: Session = Depends(get_session),
    device_id: str = Depends(get_device_id),
):
    r = _get_or_404_owner(session, reading_id, device_id)

    if len(files) < settings.min_photos or len(files) > settings.max_photos:
        raise HTTPException(
            status_code=400,
            detail=f"Foto sayısı {settings.min_photos}-{settings.max_photos} olmalı.",
        )

    saved = await save_uploads(reading_id, files)

    # ✅ Upload aşamasında AI doğrulama başarısız olursa 500 değil doğru kod dönelim.
    # ✅ Quota/servis hatasında dosyaları silmiyoruz (kullanıcı daha sonra tekrar deneyebilir).
    try:
        verdict = validate_coffee_images(saved)
    except AIInsufficientQuotaError:
        # 429 quota/billing -> 503
        raise HTTPException(
            status_code=503,
            detail="AI servis kotası şu anda yetersiz (billing/quota). Lütfen daha sonra tekrar dene.",
        )
    except AIServiceUnavailableError:
        raise HTTPException(
            status_code=503,
            detail="AI servisi geçici olarak yoğun/ulaşılamıyor. Lütfen biraz sonra tekrar dene.",
        )
    except AIServiceError:
        raise HTTPException(
            status_code=503,
            detail="AI servisinde beklenmeyen bir sorun oluştu. Lütfen daha sonra tekrar dene.",
        )

    if not verdict.get("ok"):
        # ✅ Bu gerçek bir doğrulama reddi -> burada dosyaları silmek mantıklı
        _delete_paths(saved)
        raise HTTPException(
            status_code=400,
            detail="Lütfen sadece kahve fincanı içi fotoğrafı yükleyin.",
        )

    r = set_photos(session, reading_id, saved)
    r.status = "photos_uploaded"
    r.updated_at = datetime.utcnow()
    r = update_reading(session, r)

    return _to_schema(r)


# --------------------------------------------------
# GENERATE
# --------------------------------------------------
@router.post("/{reading_id}/generate", response_model=CoffeeReading)
async def generate(
    reading_id: str,
    session: Session = Depends(get_session),
    device_id: str = Depends(get_device_id),
):
    r = _get_or_404_owner(session, reading_id, device_id)

    photos = list_photos(r)
    if not photos:
        raise HTTPException(status_code=400, detail="Fotoğraf yüklenmedi")

    # Ödeme öncesi generate’e izin ver (yorum DB’de saklanır, _to_schema ödenmemişse göstermez)
    # zaten üretildiyse dön
    if r.result_text:
        return _to_schema(r)

    # zaten işlemdeyse dön
    if r.status == "processing":
        return _to_schema(r)

    # ✅ Generate öncesi ikinci doğrulama
    try:
        verdict = validate_coffee_images(photos)
    except AIInsufficientQuotaError:
        raise HTTPException(
            status_code=503,
            detail="AI servis kotası şu anda yetersiz (billing/quota). Lütfen daha sonra tekrar dene.",
        )
    except AIServiceUnavailableError:
        raise HTTPException(
            status_code=503,
            detail="AI servisi geçici olarak yoğun/ulaşılamıyor. Lütfen biraz sonra tekrar dene.",
        )
    except AIServiceError:
        raise HTTPException(
            status_code=503,
            detail="AI servisinde beklenmeyen bir sorun oluştu. Lütfen daha sonra tekrar dene.",
        )

    if not verdict.get("ok"):
        raise HTTPException(
            status_code=400,
            detail="Lütfen sadece kahve fincanı içi fotoğrafı yükleyin.",
        )

    # ✅ artık üretime geçiyoruz
    set_status(session, reading_id, "processing")

    try:
        text = generate_fortune(
            name=r.name,
            topic=r.topic,
            question=r.question,
            image_paths=photos,
        ).strip()

        if not text:
            raise RuntimeError("Boş sonuç")

        r = set_status(session, reading_id, "completed", comment=text)
        try:
            from app.services.fcm_service import send_reading_ready_notification
            send_reading_ready_notification(device_id)
        except Exception:
            pass
        return _to_schema(r)

    except AIInsufficientQuotaError:
        # ✅ processing'de kalmasın
        set_status(session, reading_id, "paid")
        raise HTTPException(
            status_code=503,
            detail="AI servis kotası şu anda yetersiz (billing/quota). Lütfen daha sonra tekrar dene.",
        )

    except AIServiceUnavailableError:
        set_status(session, reading_id, "paid")
        raise HTTPException(
            status_code=503,
            detail="AI servisi geçici olarak yoğun/ulaşılamıyor. Lütfen biraz sonra tekrar dene.",
        )

    except AIServiceError:
        set_status(session, reading_id, "paid")
        raise HTTPException(
            status_code=503,
            detail="AI servisinde beklenmeyen bir sorun oluştu. Lütfen daha sonra tekrar dene.",
        )

    except Exception as e:
        # ✅ processing'de kalmasın
        set_status(session, reading_id, "paid")
        raise HTTPException(
            status_code=500,
            detail=f"Kahve falı üretilemedi: {e}",
        )


# --------------------------------------------------
# DETAIL
# --------------------------------------------------
@router.get("/{reading_id}", response_model=CoffeeReading)
async def detail(
    reading_id: str,
    session: Session = Depends(get_session),
    device_id: str = Depends(get_device_id),
):
    r = _get_or_404_owner(session, reading_id, device_id)
    return _to_schema(r)


# --------------------------------------------------
# RATE
# --------------------------------------------------
@router.post("/{reading_id}/rate", response_model=CoffeeReading)
async def rate(
    reading_id: str,
    req: RatingRequest,
    session: Session = Depends(get_session),
    device_id: str = Depends(get_device_id),
):
    r = _get_or_404_owner(session, reading_id, device_id)
    if not (1 <= req.rating <= 5):
        raise HTTPException(status_code=400, detail="Rating 1-5 arası olmalı")

    r.rating = req.rating
    r.updated_at = datetime.utcnow()
    r = update_reading(session, r)
    return _to_schema(r)
