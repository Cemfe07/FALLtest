# app/schemas/numerology.py
from __future__ import annotations

from typing import Optional
from pydantic import BaseModel, Field, ConfigDict


class NumerologyStartIn(BaseModel):
    """
    POST /api/v1/numerology/start
    Frontend payload:
      {
        "name": "...",
        "birth_date": "YYYY-MM-DD",
        "topic": "genel",
        "question": "..."
      }
    """
    model_config = ConfigDict(extra="ignore")

    name: str = Field(..., min_length=1)
    birth_date: str = Field(..., description="YYYY-MM-DD")
    topic: str = Field(default="genel")
    question: Optional[str] = None


class MarkPaidIn(BaseModel):
    """
    POST /api/v1/numerology/{id}/mark-paid
    """
    model_config = ConfigDict(extra="ignore")

    payment_ref: Optional[str] = None


class NumerologyReadingOut(BaseModel):
    """
    Response model (DB + API uyumlu)
    """
    model_config = ConfigDict(extra="ignore")

    id: str
    topic: str = "genel"
    question: Optional[str] = None
    name: str
    birth_date: str
    status: str

    # Ödeme öncesi maskelenen yorumun hazır olup olmadığını belirtir.
    has_result: bool = False
    result_text: Optional[str] = None
    rating: Optional[int] = None

    is_paid: bool = False
    payment_ref: Optional[str] = None
