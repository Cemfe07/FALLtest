# app/core/config.py
from __future__ import annotations

from pathlib import Path
from typing import List, Optional

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parents[2]


def _parse_csv(value: str) -> List[str]:
    value = (value or "").strip()
    if not value:
        return []
    return [x.strip() for x in value.split(",") if x.strip()]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(BASE_DIR / ".env"),
        extra="ignore",
    )

    environment: str = Field(default="dev", alias="ENVIRONMENT")
    debug: bool = Field(default=False, alias="DEBUG")

    # Storage
    storage_dir: Path = Field(default=BASE_DIR / "storage", alias="STORAGE_DIR")

    # Optional: dışarıdan override edilebilir
    upload_dir: Optional[Path] = Field(default=None, alias="UPLOAD_DIR")

    # DB
    database_url: str = Field(
        default=f"sqlite:///{(BASE_DIR / 'storage' / 'fall.db').as_posix()}",
        alias="DATABASE_URL",
    )

    # OpenAI
    openai_api_key: str = Field(default="", alias="OPENAI_API_KEY")
    openai_model: str = Field(default="gpt-4.1-mini", alias="OPENAI_MODEL")
    openai_max_output_tokens: int = Field(default=2500, alias="OPENAI_MAX_OUTPUT_TOKENS")

    # Railway timeout / retry
    openai_timeout_seconds: int = Field(default=90, alias="OPENAI_TIMEOUT_SECONDS")
    openai_max_retries: int = Field(default=2, alias="OPENAI_MAX_RETRIES")

    cors_origins_raw: str = Field(default="*", alias="CORS_ORIGINS")

    allow_stub_iap: bool = Field(default=False, alias="ALLOW_STUB_IAP")
    google_play_package_name: str = Field(default="", alias="GOOGLE_PLAY_PACKAGE_NAME")
    apple_bundle_id: str = Field(default="", alias="APPLE_BUNDLE_ID")

    # Coffee/Hand foto kuralı
    min_photos: int = 3
    max_photos: int = 5

    # FCM: Yorum hazır push bildirimi (JSON string veya boş = bildirim gönderilmez)
    firebase_credentials_json: Optional[str] = Field(default=None, alias="FIREBASE_CREDENTIALS_JSON")
    # Cron: günlük hatırlatma endpoint'i için gizli token (boş = cron kapalı)
    cron_secret: Optional[str] = Field(default=None, alias="CRON_SECRET")

    @property
    def upload_dir_effective(self) -> Path:
        # ✅ TEK KAYNAK:
        # UPLOAD_DIR verilmediyse otomatik storage/uploads
        return self.upload_dir or (self.storage_dir / "uploads")

    @property
    def cors_origins(self) -> List[str]:
        raw = (self.cors_origins_raw or "").strip()
        if raw in {"", "*"}:
            return ["*"]
        return _parse_csv(raw)

    def ensure_dirs(self) -> None:
        self.storage_dir.mkdir(parents=True, exist_ok=True)
        self.upload_dir_effective.mkdir(parents=True, exist_ok=True)


settings = Settings()
