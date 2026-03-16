from __future__ import annotations

from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field


class TarotMarkPaidRequest(BaseModel):
    # ödeme referansı mock da olsa boş gelmesin
    payment_ref: Optional[str] = None


class TarotStartRequest(BaseModel):
    topic: str = Field(default="", max_length=120)
    question: str = Field(default="", max_length=500)
    name: str = Field(default="Misafir", max_length=80)
    age: Optional[int] = None
    # three / six / twelve
    spread_type: str = Field(default="three", max_length=20)


class TarotSelectCardsRequest(BaseModel):
    # ör: ["major_18_moon|R", "major_00_fool|U", ...]
    cards: List[str]


class TarotRatingRequest(BaseModel):
    rating: int


class TarotReading(BaseModel):
    id: str
    topic: str
    question: str
    name: str
    age: Optional[int]
    spread_type: str

    selected_cards: List[str] = Field(default_factory=list)

    status: str
    has_result: bool = False
    result_text: Optional[str] = None
    rating: Optional[int] = None

    is_paid: bool
    payment_ref: Optional[str] = None

    created_at: datetime
