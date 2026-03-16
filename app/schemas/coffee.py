# app/schemas/coffee.py
from __future__ import annotations

from datetime import datetime
from typing import List, Optional, Literal

from pydantic import BaseModel, Field


CoffeeStatus = Literal[
    "pending_payment",
    "photos_uploaded",
    "paid",
    "processing",
    "completed",
]


class CoffeeStartRequest(BaseModel):
    topic: str = Field(default="Genel", max_length=80)
    question: str = Field(default="", max_length=700)
    name: str = Field(default="Misafir", max_length=80)
    age: Optional[int] = None

    # opsiyoneller (şimdilik backend DB’de tutmuyorsan sorun değil, request ile gelir)
    relationship_status: Optional[str] = None
    big_decision: Optional[str] = None


class CoffeeReading(BaseModel):
    id: str
    topic: str
    question: str
    name: str
    age: Optional[int] = None

    photos: List[str] = Field(default_factory=list)

    status: CoffeeStatus
    has_result: bool = False
    comment: Optional[str] = None
    result_text: Optional[str] = None

    rating: Optional[int] = None

    is_paid: bool = False
    payment_ref: Optional[str] = None

    created_at: datetime
