"""
api/statistics.py
-----------------
GET /api/stats?range=day|week|month

Returns aggregated statistics with chart data for the Flutter
StatisticsScreen bar charts and top-states breakdown.
"""
import logging

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from api.auth import get_current_user
from database import get_db
from models.db_models import User
from services import stats_service

logger = logging.getLogger("sentio.stats_api")
router = APIRouter()


class ChartPoint(BaseModel):
    label: str
    value: float   # focus minutes in that bucket


class StatsOut(BaseModel):
    total_focus_time_seconds:   int
    total_session_time_seconds: int
    sessions_count:             int
    dominant_state:             str
    average_confidence:         float
    state_breakdown:            dict[str, float]   # emotion → fraction 0–1
    chart_data:                 list[ChartPoint]
    focus_time_str:             str                # human-readable e.g. "4h 32m"


@router.get("/stats", response_model=StatsOut)
def get_stats(
    range: str = Query(default="week", description="day | week | month"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    data = stats_service.get_stats(db, current_user.id, range)
    return StatsOut(
        total_focus_time_seconds=data["total_focus_time_seconds"],
        total_session_time_seconds=data["total_session_time_seconds"],
        sessions_count=data["sessions_count"],
        dominant_state=data["dominant_state"],
        average_confidence=data["average_confidence"],
        state_breakdown=data["state_breakdown"],
        chart_data=[ChartPoint(**p) for p in data["chart_data"]],
        focus_time_str=data["focus_time_str"],
    )
