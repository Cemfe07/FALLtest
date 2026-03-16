from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class PersonalityStartRequest(BaseModel):
    topic: str = Field(default="genel", description="genel/aşk/para/kariyer vb.")
    question: Optional[str] = Field(default=None, description="Kullanıcının sorusu (opsiyonel)")

    name: str = Field(..., description="Ad Soyad")
    birth_date: str = Field(..., description="YYYY-MM-DD formatında doğum tarihi")
    birth_time: Optional[str] = Field(default=None, description="HH:MM (opsiyonel)")
    birth_city: str = Field(..., description="Doğum şehri")
    birth_country: str = Field(default="TR", description="Ülke kodu (varsayılan TR)")


class PersonalityMarkPaidRequest(BaseModel):
    payment_ref: Optional[str] = Field(default=None, description="Ödeme referansı (opsiyonel)")


class PersonalityRatingRequest(BaseModel):
    rating: int = Field(..., ge=1, le=5)


class PersonalityReading(BaseModel):
    id: str

    name: str
    birth_date: str
    birth_time: Optional[str]
    birth_city: str
    birth_country: str

    topic: str
    question: Optional[str]

    status: str
    has_result: bool = False
    result_text: Optional[str]

    is_paid: bool
    payment_ref: Optional[str]
    rating: Optional[int]

    created_at: datetime
    updated_at: datetime
