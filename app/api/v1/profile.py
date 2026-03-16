from __future__ import annotations

from datetime import datetime
from typing import Optional, List, Literal, Dict, Any

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlmodel import Session, select, func

from app.core.device import get_device_id
from app.db import get_session
from app.repositories import profile_repo
from app.schemas.profile import ProfileUpsertRequest, ProfileResponse

# ✅ Reading modelleri (profil summary/history için)
from app.models.coffee_db import CoffeeReadingDB
from app.models.hand_db import HandReadingDB
from app.models.tarot_db import TarotReadingDB
from app.models.numerology_db import NumerologyReadingDB
from app.models.birthchart_db import BirthChartReadingDB
from app.models.personality_db import PersonalityReadingDB
from app.models.synastry_db import SynastryReadingDB

router = APIRouter(prefix="/profile", tags=["profile"])


# =========================================================
# SCHEMAS (profile.py içinde local tuttum: ek dosya istemesin)
# =========================================================
ReadingType = Literal[
    "coffee",
    "hand",
    "tarot",
    "numerology",
    "birthchart",
    "personality",
    "synastry",
]

class ProfileCounts(BaseModel):
    total: int = 0
    paid: int = 0
    completed: int = 0


class ProfileActivityItem(BaseModel):
    type: ReadingType
    id: str
    title: str
    status: str
    is_paid: bool
    # Yoruma dair "hazır mı?" bilgisi. Kilitli/ödenmemiş olsa da true olabilir.
    has_result: bool = False
    created_at: Optional[datetime] = None
    # Ödenmiş okumalarda yorum metni (profil listesinde gösterim için)
    result_text: Optional[str] = None


class ProfileSummaryResponse(BaseModel):
    device_id: str
    counts: Dict[ReadingType, ProfileCounts]
    recent: List[ProfileActivityItem]


class ProfileHistoryResponse(BaseModel):
    device_id: str
    items: List[ProfileActivityItem]
    limit: int
    offset: int
    type: Optional[ReadingType] = None


# =========================================================
# ME (Mevcut endpointlerin aynısı)
# =========================================================
@router.get("/me", response_model=ProfileResponse)
def get_me(
    device_id: str = Depends(get_device_id),
    session: Session = Depends(get_session),
):
    obj = profile_repo.get_by_device(session, device_id)
    if obj is None:
        return ProfileResponse(
            device_id=device_id,
            display_name="Misafir",
            birth_date=None,
            birth_place=None,
            birth_time=None,
        )
    return ProfileResponse(
        device_id=obj.device_id,
        display_name=obj.display_name,
        birth_date=obj.birth_date,
        birth_place=obj.birth_place,
        birth_time=obj.birth_time,
    )


@router.post("/me", response_model=ProfileResponse)
def upsert_me(
    req: ProfileUpsertRequest,
    device_id: str = Depends(get_device_id),
    session: Session = Depends(get_session),
):
    obj = profile_repo.upsert_by_device(
        session,
        device_id=device_id,
        data=req.model_dump(),
    )
    return ProfileResponse(
        device_id=obj.device_id,
        display_name=obj.display_name,
        birth_date=obj.birth_date,
        birth_place=obj.birth_place,
        birth_time=obj.birth_time,
    )


# =========================================================
# HELPERS
# =========================================================
def _safe_str(v: Any) -> str:
    return "" if v is None else str(v)


def _normalize_status(s: Any) -> str:
    return _safe_str(s).strip() or "unknown"


def _mk_title(type_: ReadingType, obj: Any) -> str:
    # UI için kısa “başlık” üretelim
    if type_ == "coffee":
        return f"Kahve • {(_safe_str(getattr(obj, 'topic', 'Genel')) or 'Genel')}"
    if type_ == "hand":
        return f"El • {(_safe_str(getattr(obj, 'topic', 'Genel')) or 'Genel')}"
    if type_ == "tarot":
        spread = _safe_str(getattr(obj, "spread_type", "three")) or "three"
        return f"Tarot • {spread}"
    if type_ == "numerology":
        return f"Nümeroloji • {(_safe_str(getattr(obj, 'topic', 'genel')) or 'genel')}"
    if type_ == "birthchart":
        return f"Doğum Haritası • {(_safe_str(getattr(obj, 'topic', 'genel')) or 'genel')}"
    if type_ == "personality":
        return f"Kişilik • {(_safe_str(getattr(obj, 'topic', 'genel')) or 'genel')}"
    if type_ == "synastry":
        a = _safe_str(getattr(obj, "name_a", "")).strip()
        b = _safe_str(getattr(obj, "name_b", "")).strip()
        if a and b:
            return f"Sinastri • {a} & {b}"
        return "Sinastri"
    return type_


def _obj_id(obj: Any) -> str:
    # Bazı tablolarda id int olabilir (eski data). Hepsini string dönelim.
    return _safe_str(getattr(obj, "id", ""))


def _activity_item(type_: ReadingType, obj: Any) -> ProfileActivityItem:
    is_paid = bool(getattr(obj, "is_paid", False))
    raw_result = getattr(obj, "result_text", None)
    has_result = isinstance(raw_result, str) and bool(raw_result.strip())
    result_text = None
    if is_paid:
        result_text = raw_result or None
        if isinstance(result_text, str) and not result_text.strip():
            result_text = None
    return ProfileActivityItem(
        type=type_,
        id=_obj_id(obj),
        title=_mk_title(type_, obj),
        status=_normalize_status(getattr(obj, "status", "")),
        is_paid=is_paid,
        has_result=has_result,
        created_at=getattr(obj, "created_at", None),
        result_text=result_text,
    )


def _count_for_table(
    session: Session,
    model: Any,
    device_id: str,
    completed_statuses: List[str],
) -> ProfileCounts:
    # total
    total_stmt = select(func.count()).select_from(model).where(model.device_id == device_id)
    total = session.exec(total_stmt).one()

    # paid
    paid_stmt = select(func.count()).select_from(model).where(
        model.device_id == device_id,
        model.is_paid == True,  # noqa: E712
    )
    paid = session.exec(paid_stmt).one()

    # completed (status list)
    completed_stmt = select(func.count()).select_from(model).where(
        model.device_id == device_id,
        model.status.in_(completed_statuses),
    )
    completed = session.exec(completed_stmt).one()

    return ProfileCounts(total=int(total), paid=int(paid), completed=int(completed))


def _latest_for_table(
    session: Session,
    model: Any,
    device_id: str,
    limit: int,
) -> List[Any]:
    stmt = (
        select(model)
        .where(model.device_id == device_id)
        .order_by(model.created_at.desc())
        .limit(limit)
    )
    return list(session.exec(stmt).all())


# =========================================================
# SUMMARY
# =========================================================
@router.get("/summary", response_model=ProfileSummaryResponse)
def summary(
    device_id: str = Depends(get_device_id),
    session: Session = Depends(get_session),
    recent_limit: int = Query(default=12, ge=1, le=50),
):
    # status completed farklılıkları olabilir; biz toleranslı olalım
    # (bazı modüllerde completed, bazı modüllerde done vardı)
    completed_like = ["completed", "done"]

    counts: Dict[ReadingType, ProfileCounts] = {
        "coffee": _count_for_table(session, CoffeeReadingDB, device_id, completed_like),
        "hand": _count_for_table(session, HandReadingDB, device_id, completed_like),
        "tarot": _count_for_table(session, TarotReadingDB, device_id, completed_like),
        "numerology": _count_for_table(session, NumerologyReadingDB, device_id, completed_like),
        "birthchart": _count_for_table(session, BirthChartReadingDB, device_id, completed_like),
        "personality": _count_for_table(session, PersonalityReadingDB, device_id, completed_like),
        "synastry": _count_for_table(session, SynastryReadingDB, device_id, completed_like),
    }

    # Her tablodan son N çekip tek listede merge edeceğiz
    per_table = max(3, min(10, recent_limit))  # güvenli
    recent_objs: List[ProfileActivityItem] = []

    for t, model in [
        ("coffee", CoffeeReadingDB),
        ("hand", HandReadingDB),
        ("tarot", TarotReadingDB),
        ("numerology", NumerologyReadingDB),
        ("birthchart", BirthChartReadingDB),
        ("personality", PersonalityReadingDB),
        ("synastry", SynastryReadingDB),
    ]:
        rows = _latest_for_table(session, model, device_id, per_table)
        recent_objs.extend([_activity_item(t, r) for r in rows])  # type: ignore[arg-type]

    # global sort + limit
    recent_objs.sort(key=lambda x: x.created_at or datetime.min, reverse=True)
    recent_objs = recent_objs[:recent_limit]

    return ProfileSummaryResponse(device_id=device_id, counts=counts, recent=recent_objs)


# =========================================================
# HISTORY (Opsiyonel filtre)
# =========================================================
@router.get("/history", response_model=ProfileHistoryResponse)
def history(
    device_id: str = Depends(get_device_id),
    session: Session = Depends(get_session),
    type: Optional[ReadingType] = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
):
    # type verilirse tek tablodan al
    model_map = {
        "coffee": CoffeeReadingDB,
        "hand": HandReadingDB,
        "tarot": TarotReadingDB,
        "numerology": NumerologyReadingDB,
        "birthchart": BirthChartReadingDB,
        "personality": PersonalityReadingDB,
        "synastry": SynastryReadingDB,
    }

    items: List[ProfileActivityItem] = []

    if type:
        model = model_map[type]
        stmt = (
            select(model)
            .where(model.device_id == device_id)
            .order_by(model.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        rows = list(session.exec(stmt).all())
        items = [_activity_item(type, r) for r in rows]
        return ProfileHistoryResponse(device_id=device_id, items=items, limit=limit, offset=offset, type=type)

    # type yoksa: hepsinden “offset+limit” gibi paginate merge zor.
    # Bu yüzden pratik çözüm: her tablodan (offset+limit) kadar çek, merge-sort, sonra slice.
    # (Profil ekranı için fazlasıyla yeterli.)
    fetch = min(200, offset + limit)

    for t, model in model_map.items():
        stmt = (
            select(model)
            .where(model.device_id == device_id)
            .order_by(model.created_at.desc())
            .limit(fetch)
        )
        rows = list(session.exec(stmt).all())
        items.extend([_activity_item(t, r) for r in rows])  # type: ignore[arg-type]

    items.sort(key=lambda x: x.created_at or datetime.min, reverse=True)
    items = items[offset : offset + limit]

    return ProfileHistoryResponse(device_id=device_id, items=items, limit=limit, offset=offset, type=None)
