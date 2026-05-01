"""
api/users.py
------------
User profile and session-log management.

  GET    /api/users/me                   — profile
  PATCH  /api/users/me                   — update name / avatar
  DELETE /api/users/me                   — soft-delete account

  GET    /api/users/me/sessions          — paginated session history
  POST   /api/users/me/sessions          — log a completed EEG session
  GET    /api/users/me/sessions/{id}     — single session detail
  DELETE /api/users/me/sessions/{id}     — delete a session log

  GET    /api/users/me/stats             — aggregated statistics
"""
import logging
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import func
from sqlalchemy.orm import Session

from api.auth import UserOut, get_current_user
from database import get_db
from models.db_models import SessionLog, User

logger = logging.getLogger("sentio.users")
router = APIRouter()


# =============================================================================
# Pydantic schemas
# =============================================================================

class UserUpdateIn(BaseModel):
    name:       Optional[str] = None
    avatar_url: Optional[str] = None


class SessionLogIn(BaseModel):
    session_type:     str            = "monitoring"
    start_time:       Optional[datetime] = None
    end_time:         Optional[datetime] = None
    duration_seconds: Optional[int]  = None
    dominant_emotion: Optional[str]  = None
    avg_confidence:   Optional[float] = None
    avg_alpha:        Optional[float] = None
    avg_beta:         Optional[float] = None
    avg_theta:        Optional[float] = None
    avg_gamma:        Optional[float] = None
    notes:            Optional[str]  = None


class SessionLogOut(BaseModel):
    id:               str
    user_id:          str
    session_type:     str
    start_time:       datetime
    end_time:         Optional[datetime]
    duration_seconds: Optional[int]
    dominant_emotion: Optional[str]
    avg_confidence:   Optional[float]
    avg_alpha:        Optional[float]
    avg_beta:         Optional[float]
    avg_theta:        Optional[float]
    avg_gamma:        Optional[float]
    notes:            Optional[str]
    created_at:       datetime

    model_config = {"from_attributes": True}


class StatsOut(BaseModel):
    total_sessions:    int
    total_seconds:     int
    avg_confidence:    Optional[float]
    emotion_breakdown: dict[str, int]   # emotion → session count
    most_common_emotion: Optional[str]


# =============================================================================
# Profile endpoints
# =============================================================================

@router.get("/me", response_model=UserOut)
def get_profile(current_user: User = Depends(get_current_user)):
    return UserOut.model_validate(current_user)


@router.patch("/me", response_model=UserOut)
def update_profile(
    payload: UserUpdateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if payload.name is not None:
        current_user.name = payload.name
    if payload.avatar_url is not None:
        current_user.avatar_url = payload.avatar_url
    db.commit()
    db.refresh(current_user)
    logger.info("Profile updated  user_id=%s", current_user.id)
    return UserOut.model_validate(current_user)


@router.delete("/me", status_code=204)
def delete_account(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Soft-delete: sets is_active=False so historical data is preserved."""
    current_user.is_active = False
    db.commit()
    logger.info("Account deactivated  user_id=%s", current_user.id)


# =============================================================================
# Session log endpoints
# =============================================================================

@router.get("/me/sessions", response_model=list[SessionLogOut])
def list_sessions(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    limit:  int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    emotion: Optional[str] = Query(default=None, description="Filter by dominant emotion"),
):
    q = (
        db.query(SessionLog)
        .filter(SessionLog.user_id == current_user.id)
        .order_by(SessionLog.created_at.desc())
    )
    if emotion:
        q = q.filter(SessionLog.dominant_emotion == emotion)
    return q.offset(offset).limit(limit).all()


@router.post("/me/sessions", response_model=SessionLogOut, status_code=201)
def create_session(
    payload: SessionLogIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    log = SessionLog(
        user_id          = current_user.id,
        session_type     = payload.session_type,
        start_time       = payload.start_time or datetime.now(tz=timezone.utc),
        end_time         = payload.end_time,
        duration_seconds = payload.duration_seconds,
        dominant_emotion = payload.dominant_emotion,
        avg_confidence   = payload.avg_confidence,
        avg_alpha        = payload.avg_alpha,
        avg_beta         = payload.avg_beta,
        avg_theta        = payload.avg_theta,
        avg_gamma        = payload.avg_gamma,
        notes            = payload.notes,
    )
    db.add(log)
    db.commit()
    db.refresh(log)
    logger.info(
        "Session logged  user_id=%s  emotion=%s  dur=%ss",
        current_user.id, log.dominant_emotion, log.duration_seconds,
    )
    return log


@router.get("/me/sessions/{session_id}", response_model=SessionLogOut)
def get_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    log = (
        db.query(SessionLog)
        .filter(
            SessionLog.id == session_id,
            SessionLog.user_id == current_user.id,
        )
        .first()
    )
    if not log:
        raise HTTPException(404, "Session not found")
    return log


@router.delete("/me/sessions/{session_id}", status_code=204)
def delete_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    log = (
        db.query(SessionLog)
        .filter(
            SessionLog.id == session_id,
            SessionLog.user_id == current_user.id,
        )
        .first()
    )
    if not log:
        raise HTTPException(404, "Session not found")
    db.delete(log)
    db.commit()


# =============================================================================
# Statistics endpoint
# =============================================================================

@router.get("/me/stats", response_model=StatsOut)
def get_stats(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    logs = (
        db.query(SessionLog)
        .filter(SessionLog.user_id == current_user.id)
        .all()
    )

    total_sessions = len(logs)
    total_seconds  = sum(s.duration_seconds or 0 for s in logs)
    confidences    = [s.avg_confidence for s in logs if s.avg_confidence is not None]
    avg_conf       = round(sum(confidences) / len(confidences), 2) if confidences else None

    emotion_counts: dict[str, int] = {}
    for s in logs:
        if s.dominant_emotion:
            emotion_counts[s.dominant_emotion] = (
                emotion_counts.get(s.dominant_emotion, 0) + 1
            )

    most_common = (
        max(emotion_counts, key=emotion_counts.get)
        if emotion_counts else None
    )

    return StatsOut(
        total_sessions      = total_sessions,
        total_seconds       = total_seconds,
        avg_confidence      = avg_conf,
        emotion_breakdown   = emotion_counts,
        most_common_emotion = most_common,
    )
