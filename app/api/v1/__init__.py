# app/api/v1/__init__.py
from fastapi import APIRouter

from app.api.v1.routes_coffee import router as coffee_router
from app.api.v1.routes_hand import router as hand_router
from app.api.v1.routes_tarot import router as tarot_router
from app.api.v1.routes_numerology import router as numerology_router
from app.api.v1.routes_birthchart import router as birthchart_router
from app.api.v1.routes_personality import router as personality_router
from app.api.v1.routes_payments import router as payments_router
from app.api.v1.routes_synastry import router as synastry_router
from app.api.v1.routes_admin import router as admin_router  # ✅ NEW
from app.api.v1.profile import router as profile_router
from app.api.v1.legal import router as legal_router
from app.api.v1.routes_notifications import router as notifications_router
from app.api.v1.routes_cron import router as cron_router

api_router = APIRouter()

api_router.include_router(coffee_router)
api_router.include_router(hand_router)
api_router.include_router(tarot_router)
api_router.include_router(numerology_router)
api_router.include_router(birthchart_router)
api_router.include_router(personality_router)
api_router.include_router(payments_router)
api_router.include_router(synastry_router)
api_router.include_router(admin_router)  # ✅ NEW
api_router.include_router(profile_router)
api_router.include_router(legal_router)
api_router.include_router(notifications_router)
api_router.include_router(cron_router)