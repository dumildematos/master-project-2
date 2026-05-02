"""
api/dashboard.py
----------------
GET /api/dashboard/summary

Returns today's aggregate metrics + the latest live state from the
WebSocket frame buffer, ready for the Flutter dashboard screen.
"""
import logging
from typing import Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from api.auth import get_current_user
from database import get_db
from models.db_models import User
from services import stats_service

logger = logging.getLogger("sentio.dashboard_api")
router = APIRouter()


class _LastSession(BaseModel):
    session_id:         str
    title:              Optional[str]
    duration_seconds:   Optional[int]
    dominant_state:     Optional[str]
    average_confidence: Optional[float]
    ended_at:           Optional[str]


class DashboardSummaryOut(BaseModel):
    current_state:      str          # live emotion from WebSocket buffer
    current_confidence: float        # 0–100
    focus_time_today:   int          # seconds of focused state today
    total_time_today:   int          # total session seconds today
    top_state_today:    str          # dominant emotion today
    sessions_today:     int
    last_session:       Optional[_LastSession]


@router.get("/dashboard/summary", response_model=DashboardSummaryOut)
def dashboard_summary(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    data = stats_service.get_dashboard_summary(db, current_user.id)
    last = data.get("last_session")
    return DashboardSummaryOut(
        current_state=data["current_state"],
        current_confidence=float(data["current_confidence"]),
        focus_time_today=int(data["focus_time_today"]),
        total_time_today=int(data["total_time_today"]),
        top_state_today=data["top_state_today"],
        sessions_today=int(data["sessions_today"]),
        last_session=_LastSession(**last) if last else None,
    )
