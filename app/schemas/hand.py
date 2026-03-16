from __future__ import annotations
from typing import List, Optional
from datetime import datetime
from pydantic import BaseModel


class HandStartRequest(BaseModel):
    name: str
    age: Optional[int] = None
    topic: str
    question: str
    dominant_hand: Optional[str] = None
    photo_hand: Optional[str] = None
    relationship_status: Optional[str] = None
    big_decision: Optional[str] = None


class HandReading(BaseModel):
    id: str
    topic: str
    question: str
    name: str
    age: Optional[int] = None

    dominant_hand: Optional[str] = None
    photo_hand: Optional[str] = None

    photos: List[str] = []
    status: str
    has_result: bool = False
    comment: Optional[str] = None
    result_text: Optional[str] = None
    rating: Optional[int] = None

    is_paid: bool = False
    payment_ref: Optional[str] = None
    created_at: Optional[datetime] = None
