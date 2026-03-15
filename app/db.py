from __future__ import annotations

from typing import Generator, Dict, Optional

from sqlalchemy import text
from sqlmodel import SQLModel, Session, create_engine

from app.core.config import settings

# ✅ MODELLERİ IMPORT ET (create_all için şart)
from app.models.coffee_db import CoffeeReadingDB  # noqa: F401
from app.models.hand_db import HandReadingDB  # noqa: F401
from app.models.tarot_db import TarotReadingDB  # noqa: F401
from app.models.numerology_db import NumerologyReadingDB  # noqa: F401
from app.models.birthchart_db import BirthChartReadingDB  # noqa: F401
from app.models.personality_db import PersonalityReadingDB  # noqa: F401
from app.models.synastry_db import SynastryReadingDB  # noqa: F401
from app.models.payment_db import PaymentDB  # noqa: F401
from app.models.profile_db import UserProfileDB  # noqa: F401
from app.models.legal_consent_db import LegalConsentDB  # noqa: F401


def _normalize_database_url(url: str) -> str:
    if not url:
        return url

    if url.startswith("postgres://"):
        url = "postgresql://" + url[len("postgres://") :]

    # zaten driver belirtilmişse dokunma
    if url.startswith("postgresql+"):
        return url

    if url.startswith("postgresql://"):
        return "postgresql+psycopg://" + url[len("postgresql://") :]

    return url


db_url = _normalize_database_url(settings.database_url)

connect_args = {}
if db_url.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

engine = create_engine(
    db_url,
    echo=False,
    connect_args=connect_args,
)


def get_session() -> Generator[Session, None, None]:
    with Session(engine) as session:
        yield session


# ==========================================================
# DIALECT HELPERS
# ==========================================================
def _is_sqlite() -> bool:
    return db_url.startswith("sqlite")


def _is_postgres() -> bool:
    return db_url.startswith("postgresql")


# ---------------- SQLITE HELPERS ----------------
def _sqlite_has_table(table: str) -> bool:
    if not _is_sqlite():
        return False
    q = text("SELECT name FROM sqlite_master WHERE type='table' AND name=:t;")
    with engine.connect() as conn:
        row = conn.execute(q, {"t": table}).fetchone()
    return row is not None


def _sqlite_has_column(table: str, column: str) -> bool:
    if not _is_sqlite():
        return False
    q = text(f"PRAGMA table_info({table});")
    with engine.connect() as conn:
        rows = conn.execute(q).fetchall()
    cols = {r[1] for r in rows}
    return column in cols


def _sqlite_add_cols(table: str, alters: list[str]) -> None:
    if not alters:
        print(f"[DB] {table} schema OK.")
        return
    with engine.begin() as conn:
        for stmt in alters:
            conn.execute(text(stmt))
    print(f"[DB] {table} altered: {len(alters)} changes applied.")


# ---------------- POSTGRES HELPERS ----------------
def _pg_has_table(table: str) -> bool:
    if not _is_postgres():
        return False
    q = text(
        """
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema='public' AND table_name=:t
        LIMIT 1;
    """
    )
    with engine.connect() as conn:
        row = conn.execute(q, {"t": table}).fetchone()
    return row is not None


def _pg_has_column(table: str, column: str) -> bool:
    if not _is_postgres():
        return False
    q = text(
        """
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema='public'
          AND table_name=:t
          AND column_name=:c
        LIMIT 1;
    """
    )
    with engine.connect() as conn:
        row = conn.execute(q, {"t": table, "c": column}).fetchone()
    return row is not None


def _pg_column_type(table: str, column: str) -> Optional[str]:
    """
    returns: 'integer', 'bigint', 'character varying', 'text', ...
    """
    if not _is_postgres():
        return None
    q = text(
        """
        SELECT data_type
        FROM information_schema.columns
        WHERE table_schema='public'
          AND table_name=:t
          AND column_name=:c
        LIMIT 1;
    """
    )
    with engine.connect() as conn:
        row = conn.execute(q, {"t": table, "c": column}).fetchone()
    return row[0] if row else None


def _pg_add_cols(table: str, alters: list[str]) -> None:
    if not alters:
        print(f"[DB] {table} schema OK.")
        return
    with engine.begin() as conn:
        for stmt in alters:
            conn.execute(text(stmt))
    print(f"[DB] {table} altered: {len(alters)} changes applied.")


def _ensure_columns(table: str, columns: Dict[str, str]) -> None:
    if _is_sqlite():
        if not _sqlite_has_table(table):
            return
        alters: list[str] = []
        for col, coltype in columns.items():
            if not _sqlite_has_column(table, col):
                ct = "DATETIME" if coltype == "TIMESTAMP" else coltype
                alters.append(f"ALTER TABLE {table} ADD COLUMN {col} {ct};")
        _sqlite_add_cols(table, alters)
        return

    if _is_postgres():
        if not _pg_has_table(table):
            return
        alters: list[str] = []
        for col, coltype in columns.items():
            if not _pg_has_column(table, col):
                alters.append(f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {col} {coltype};")
        _pg_add_cols(table, alters)
        return


# ==========================================================
# ✅ Fix legacy SERIAL/INTEGER/BIGINT id -> VARCHAR
# ==========================================================
def ensure_id_varchar(table: str) -> None:
    if not _is_postgres():
        return
    if not _pg_has_table(table):
        return
    if not _pg_has_column(table, "id"):
        return

    dtype = _pg_column_type(table, "id")
    if dtype in ("integer", "bigint"):
        print(f"[DB] {table}.id is {dtype} -> converting to VARCHAR...")

        with engine.begin() as conn:
            try:
                conn.execute(text(f"ALTER TABLE {table} ALTER COLUMN id DROP IDENTITY IF EXISTS;"))
            except Exception:
                pass

            try:
                conn.execute(text(f"ALTER TABLE {table} ALTER COLUMN id DROP DEFAULT;"))
            except Exception:
                pass

            conn.execute(
                text(
                    f"""
                    ALTER TABLE {table}
                      ALTER COLUMN id TYPE VARCHAR
                      USING id::text;
                    """
                )
            )

        print(f"[DB] {table}.id converted to VARCHAR.")


# ==========================================================
# ✅ FIX: legacy synastry_readings.reading_id NOT NULL
# ==========================================================
def ensure_fix_legacy_synastry_reading_id() -> None:
    if not _is_postgres():
        return
    if not _pg_has_table("synastry_readings"):
        return
    if not _pg_has_column("synastry_readings", "reading_id"):
        return

    print("[DB] legacy synastry_readings.reading_id detected -> fixing...")

    try:
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE synastry_readings DROP COLUMN IF EXISTS reading_id;"))
        print("[DB] synastry_readings.reading_id dropped.")
        return
    except Exception as e:
        print(f"[DB] DROP reading_id failed, fallback to nullable. reason={e}")

    with engine.begin() as conn:
        try:
            conn.execute(text("ALTER TABLE synastry_readings ALTER COLUMN reading_id DROP DEFAULT;"))
        except Exception:
            pass
        try:
            conn.execute(text("ALTER TABLE synastry_readings ALTER COLUMN reading_id DROP IDENTITY IF EXISTS;"))
        except Exception:
            pass
        try:
            conn.execute(text("ALTER TABLE synastry_readings ALTER COLUMN reading_id DROP NOT NULL;"))
        except Exception:
            pass

    print("[DB] synastry_readings.reading_id is now nullable (fallback).")


# ==========================================================
# SCHEMA ENSURE
# ==========================================================
def ensure_coffee_schema() -> None:
    _ensure_columns(
        "coffee_readings",
        {
            "device_id": "VARCHAR",
            "created_at": "TIMESTAMP",
            "updated_at": "TIMESTAMP",
            "is_paid": "BOOLEAN",
            "payment_ref": "VARCHAR",
            "status": "VARCHAR",
            "result_text": "TEXT",
            "rating": "INTEGER",
            "images_json": "TEXT",
            "name": "VARCHAR",
            "age": "INTEGER",
            "topic": "VARCHAR",
            "question": "TEXT",
        },
    )


def ensure_hand_schema() -> None:
    _ensure_columns(
        "hand_readings",
        {
            "device_id": "VARCHAR",
            "dominant_hand": "VARCHAR",
            "photo_hand": "VARCHAR",
            "relationship_status": "VARCHAR",
            "big_decision": "VARCHAR",
            "created_at": "TIMESTAMP",
            "updated_at": "TIMESTAMP",
            "is_paid": "BOOLEAN",
            "payment_ref": "VARCHAR",
            "status": "VARCHAR",
            "result_text": "TEXT",
            "rating": "INTEGER",
            "images_json": "TEXT",
            "name": "VARCHAR",
            "age": "INTEGER",
            "topic": "VARCHAR",
            "question": "TEXT",
        },
    )


def ensure_tarot_schema() -> None:
    _ensure_columns(
        "tarot_readings",
        {
            "device_id": "VARCHAR",
            "name": "VARCHAR",
            "age": "INTEGER",
            "topic": "VARCHAR",
            "question": "TEXT",
            "spread_type": "VARCHAR",
            "cards_json": "TEXT",
            "is_paid": "BOOLEAN",
            "payment_ref": "VARCHAR",
            "status": "VARCHAR",
            "result_text": "TEXT",
            "rating": "INTEGER",
            "created_at": "TIMESTAMP",
            "updated_at": "TIMESTAMP",
        },
    )


def ensure_numerology_schema() -> None:
    _ensure_columns(
        "numerology_readings",
        {
            "device_id": "VARCHAR",
            "payment_ref": "VARCHAR",
            "rating": "INTEGER",
            "result_text": "TEXT",
            "created_at": "TIMESTAMP",
            "updated_at": "TIMESTAMP",
            "status": "VARCHAR",
            "question": "TEXT",
            "name": "VARCHAR",
            "birth_date": "VARCHAR",
            "topic": "VARCHAR",
            "is_paid": "BOOLEAN",
        },
    )


def ensure_birthchart_schema() -> None:
    _ensure_columns(
        "birthchart_readings",
        {
            "device_id": "VARCHAR",
            "birth_time": "VARCHAR",
            "payment_ref": "VARCHAR",
            "rating": "INTEGER",
            "result_text": "TEXT",
            "created_at": "TIMESTAMP",
            "updated_at": "TIMESTAMP",
            "status": "VARCHAR",
            "question": "TEXT",
            "name": "VARCHAR",
            "birth_date": "VARCHAR",
            "birth_place": "VARCHAR",
            "topic": "VARCHAR",
            "is_paid": "BOOLEAN",
        },
    )


def ensure_personality_schema() -> None:
    _ensure_columns(
        "personality_readings",
        {
            "device_id": "VARCHAR",
            "payment_ref": "VARCHAR",
            "rating": "INTEGER",
            "result_text": "TEXT",
            "created_at": "TIMESTAMP",
            "updated_at": "TIMESTAMP",
            "status": "VARCHAR",
            "question": "TEXT",
            "name": "VARCHAR",
            "birth_date": "VARCHAR",
            "birth_time": "VARCHAR",
            "birth_city": "VARCHAR",     # ✅ FIX
            "birth_country": "VARCHAR",  # ✅ FIX
            "topic": "VARCHAR",
            "is_paid": "BOOLEAN",
        },
    )


def ensure_synastry_schema() -> None:
    _ensure_columns(
        "synastry_readings",
        {
            "device_id": "VARCHAR",
            "name_a": "VARCHAR",
            "birth_date_a": "VARCHAR",
            "birth_time_a": "VARCHAR",
            "birth_city_a": "VARCHAR",
            "birth_country_a": "VARCHAR",
            "name_b": "VARCHAR",
            "birth_date_b": "VARCHAR",
            "birth_time_b": "VARCHAR",
            "birth_city_b": "VARCHAR",
            "birth_country_b": "VARCHAR",
            "topic": "VARCHAR",
            "question": "TEXT",
            "is_paid": "BOOLEAN",
            "payment_ref": "VARCHAR",
            "status": "VARCHAR",
            "result_text": "TEXT",
            "rating": "INTEGER",
            "created_at": "TIMESTAMP",
            "updated_at": "TIMESTAMP",
        },
    )


def ensure_payments_schema() -> None:
    _ensure_columns(
        "payments",
        {
            "device_id": "VARCHAR",
            "reading_id": "VARCHAR",
            "product": "VARCHAR",
            "sku": "VARCHAR",
            "amount": "DOUBLE PRECISION",
            "currency": "VARCHAR",
            "status": "VARCHAR",
            "platform": "VARCHAR",
            "transaction_id": "VARCHAR",
            "purchase_token": "VARCHAR",
            "receipt_data": "TEXT",
            "created_at": "TIMESTAMP",
            "verified_at": "TIMESTAMP",
        },
    )


def ensure_profile_schema() -> None:
    _ensure_columns(
        "user_profiles",
        {
            "device_id": "VARCHAR",
            "display_name": "VARCHAR",
            "birth_date": "VARCHAR",
            "birth_place": "VARCHAR",
            "birth_time": "VARCHAR",
            "fcm_token": "TEXT",
            "created_at": "TIMESTAMP",
            "updated_at": "TIMESTAMP",
        },
    )


def ensure_legal_consent_schema() -> None:
    _ensure_columns(
        "legal_consents",
        {
            "device_id": "VARCHAR",
            "document_type": "VARCHAR",
            "document_version": "VARCHAR",
            "accepted_at": "TIMESTAMP",
        },
    )


def ensure_profile_constraints() -> None:
    if not _is_postgres():
        return
    if not _pg_has_table("user_profiles"):
        return

    with engine.begin() as conn:
        conn.execute(
            text(
                """
                CREATE UNIQUE INDEX IF NOT EXISTS ux_user_profiles_device_id
                ON user_profiles (device_id);
                """
            )
        )


def init_db() -> None:
    try:
        if db_url.startswith("sqlite"):
            print(f"[DB] database_url = {db_url}")
        else:
            print(f"[DB] database_url = {db_url} (non-sqlite)")
    except Exception as e:
        print(f"[DB] Could not read database info: {e}")

    if _is_sqlite():
        SQLModel.metadata.create_all(engine)

        ensure_coffee_schema()
        ensure_hand_schema()
        ensure_tarot_schema()
        ensure_numerology_schema()
        ensure_birthchart_schema()
        ensure_personality_schema()
        ensure_synastry_schema()
        ensure_payments_schema()
        ensure_profile_schema()
        return

    LOCK_KEY = 91520260115

    with engine.connect() as conn:
        conn.execute(text("SELECT pg_advisory_lock(:k)"), {"k": LOCK_KEY})
        try:
            SQLModel.metadata.create_all(engine)

            for t in (
                "synastry_readings",
                "user_profiles",
                "payments",
                "tarot_readings",
                "coffee_readings",
                "hand_readings",
                "numerology_readings",
                "birthchart_readings",
                "personality_readings",
                "legal_consents",
            ):
                ensure_id_varchar(t)

            ensure_fix_legacy_synastry_reading_id()

            ensure_coffee_schema()
            ensure_hand_schema()
            ensure_tarot_schema()
            ensure_numerology_schema()
            ensure_birthchart_schema()
            ensure_personality_schema()
            ensure_synastry_schema()
            ensure_payments_schema()
            ensure_profile_schema()
            ensure_legal_consent_schema()

            ensure_profile_constraints()
        finally:
            conn.execute(text("SELECT pg_advisory_unlock(:k)"), {"k": LOCK_KEY})
