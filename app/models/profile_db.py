# app/models/profile_db.py
from __future__ import annotations

from datetime import datetime
from typing import Optional
import uuid

from sqlmodel import SQLModel, Field


class UserProfileDB(SQLModel, table=True):
    __tablename__ = "user_profiles"

    id: str = Field(
        default_factory=lambda: str(uuid.uuid4()),
        primary_key=True,
        index=True,
    )

    # cihaz bazlı kimlik (üyelik yok)
    device_id: str = Field(
        index=True,
        unique=True,
        max_length=80,
        description="Mobil cihaz kimliği (X-Device-Id)",
    )

    display_name: str = Field(default="Misafir", max_length=80)

    # opsiyonel bilgiler (string format validasyonu mobilde yapılır)
    birth_date: Optional[str] = Field(default=None, max_length=10)  # YYYY-MM-DD
    birth_place: Optional[str] = Field(default=None, max_length=120)
    birth_time: Optional[str] = Field(default=None, max_length=5)  # HH:MM

    fcm_token: Optional[str] = Field(default=None, max_length=512)

    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
