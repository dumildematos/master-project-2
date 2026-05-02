"""
api/sessions_lifecycle.py
--------------------------
Session recording lifecycle — separate from the BrainFlow stream management.

  POST /api/sessions/start                       — create a DB session record
  POST /api/sessions/{session_id}/sample         — explicit sample upload (mobile path)
  POST /api/sessions/{session_id}/end            — finalise + compute summary
  GET  /api/sessions/history?range=...           — filtered session list
  GET  /api/sessions/active                      — active session + live LED pattern
  GET  /api/sessions/{session_id}/timeline       — per-sample emotion timeline
  GET  /api/sessions/{session_id}/latest-pattern — current LED pattern for a session
"""
import logging
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from api.auth import get_current_user
from database import get_db
from models.db_models import SessionLog as SessionLogModel, User
from services import session_service, stats_service

logger = logging.getLogger("sentio.sessions_api")
router = APIRouter()


# ── Pydantic schemas ──────────────────────────────────────────────────────────

class SessionStartIn(BaseModel):
    title: Optional[str] = None   # e.g. "Meditation", "Focus Work"


class SessionStartOut(BaseModel):
    session_id: str
    started_at: str


class SampleIn(BaseModel):
    delta:            float
    theta:            float
    alpha:            float
    beta:             float
    gamma:            float
    attention_score:  Optional[float] = None
    relaxation_score: Optional[float] = None
    stress_score:     Optional[float] = None
    detected_state:   Optional[str]   = None
    confidence:       Optional[float] = 0.0
    timestamp:        Optional[str]   = None


class SampleOut(BaseModel):
    saved: bool


class SessionEndOut(BaseModel):
    session_id:           str
    duration_seconds:     Optional[int]
    dominant_state:       Optional[str]
    average_confidence:   Optional[float]
    focus_time_seconds:   Optional[int]
    calm_time_seconds:    Optional[int]
    relaxed_time_seconds: Optional[int]
    stressed_time_seconds: Optional[int]
    excited_time_seconds: Optional[int]


class SessionHistoryItem(BaseModel):
    session_id:         str
    title:              Optional[str]
    started_at:         str
    ended_at:           Optional[str]
    duration_seconds:   Optional[int]
    dominant_state:     Optional[str]
    average_confidence: Optional[float]
    focus_time_seconds: Optional[int]


class TimelineEntry(BaseModel):
    timestamp:      str
    detected_state: Optional[str]
    confidence:     Optional[float]
    delta:          Optional[float]
    theta:          Optional[float]
    alpha:          Optional[float]
    beta:           Optional[float]
    gamma:          Optional[float]


class SessionLedPatternOut(BaseModel):
    emotion:         str
    confidence:      int
    mode:            str
    mode_name:       str
    brightness:      int
    speed:           int
    primary_color:   str
    secondary_color: str
    grid:            list
    updated_at:      str


class SessionActiveOut(BaseModel):
    active:             bool
    session_id:         Optional[str]         = None
    started_at:         Optional[str]         = None
    duration_seconds:   Optional[int]         = None
    current_state:      Optional[str]         = None
    current_confidence: Optional[float]       = None
    latest_pattern:     Optional[SessionLedPatternOut] = None


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("/sessions/start", response_model=SessionStartOut, status_code=201)
def start_session(
    payload: SessionStartIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a new session record and mark it active for stream persistence."""
    log = session_service.create_session(db, current_user.id, title=payload.title)
    return SessionStartOut(
        session_id=log.id,
        started_at=log.start_time.isoformat(),
    )


@router.post("/sessions/{session_id}/sample", response_model=SampleOut)
def add_sample(
    session_id: str,
    payload: SampleIn,
    current_user: User = Depends(get_current_user),
):
    """
    Explicitly upload one processed EEG sample (mobile/manual path).
    The stream pipeline uses save_sample_from_stream() internally;
    this endpoint is the REST equivalent for the Flutter app.
    """
    features = {
        "delta": payload.delta,
        "theta": payload.theta,
        "alpha": payload.alpha,
        "beta":  payload.beta,
        "gamma": payload.gamma,
    }
    session_service.save_sample_from_stream(
        db_session_id=session_id,
        features=features,
        emotion=payload.detected_state or "neutral",
        confidence=payload.confidence or 0.0,
    )
    return SampleOut(saved=True)


@router.post("/sessions/{session_id}/end", response_model=SessionEndOut)
def end_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Finalise the session: compute summary from samples and update the DB record."""
    try:
        log = session_service.end_session(db, session_id, current_user.id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))

    return SessionEndOut(
        session_id=log.id,
        duration_seconds=log.duration_seconds,
        dominant_state=log.dominant_emotion,
        average_confidence=log.avg_confidence,
        focus_time_seconds=log.focus_time_seconds,
        calm_time_seconds=log.calm_time_seconds,
        relaxed_time_seconds=log.relaxed_time_seconds,
        stressed_time_seconds=log.stressed_time_seconds,
        excited_time_seconds=log.excited_time_seconds,
    )


@router.post("/sessions/{session_id}/stop", response_model=SessionEndOut)
def stop_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """User-initiated stop: compute final metrics and mark session as stopped."""
    try:
        log = session_service.stop_session(db, session_id, current_user.id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))

    return SessionEndOut(
        session_id=log.id,
        duration_seconds=log.duration_seconds,
        dominant_state=log.dominant_emotion,
        average_confidence=log.avg_confidence,
        focus_time_seconds=log.focus_time_seconds,
        calm_time_seconds=log.calm_time_seconds,
        relaxed_time_seconds=log.relaxed_time_seconds,
        stressed_time_seconds=log.stressed_time_seconds,
        excited_time_seconds=log.excited_time_seconds,
    )


@router.delete("/sessions/{session_id}")
def delete_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Soft-delete a session (sets deleted_at). Excluded from all future queries."""
    try:
        session_service.delete_session(db, session_id, current_user.id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    return {"deleted": True}


@router.get("/sessions/history", response_model=list[SessionHistoryItem])
def get_history(
    range: str = Query(default="week", description="day | week | month"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return completed sessions filtered by date range."""
    logs = stats_service.get_session_history(db, current_user.id, range)
    return [
        SessionHistoryItem(
            session_id=s.id,
            title=s.session_title or s.session_type,
            started_at=s.start_time.isoformat(),
            ended_at=s.end_time.isoformat() if s.end_time else None,
            duration_seconds=s.duration_seconds,
            dominant_state=s.dominant_emotion,
            average_confidence=s.avg_confidence,
            focus_time_seconds=s.focus_time_seconds,
        )
        for s in logs
    ]


@router.get("/sessions/active", response_model=SessionActiveOut)
def get_active_session(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return the user's active session plus a live LED pattern generated from the stream."""
    from services.session_manager import session_manager
    from services.session_pattern_service import generate_pattern

    log = (
        db.query(SessionLogModel)
        .filter(
            SessionLogModel.user_id == current_user.id,
            SessionLogModel.status == "active",
            SessionLogModel.deleted_at.is_(None),
            SessionLogModel.end_time.is_(None),
        )
        .order_by(SessionLogModel.start_time.desc())
        .first()
    )

    if log is None:
        return SessionActiveOut(active=False)

    now = datetime.now(timezone.utc)
    start = log.start_time if log.start_time.tzinfo else log.start_time.replace(tzinfo=timezone.utc)
    duration_s = max(0, int((now - start).total_seconds()))

    # Prefer live stream data; fall back to DB dominant emotion
    msg        = session_manager.get_latest_stream_message()
    emotion    = (msg or {}).get("emotion") or log.dominant_emotion or "calm"
    confidence = float((msg or {}).get("confidence") or log.avg_confidence or 0.5)

    pattern = generate_pattern(emotion, confidence)

    return SessionActiveOut(
        active=True,
        session_id=log.id,
        started_at=start.isoformat(),
        duration_seconds=duration_s,
        current_state=emotion,
        current_confidence=round(confidence, 3),
        latest_pattern=SessionLedPatternOut(**pattern),
    )


@router.get("/sessions/{session_id}/latest-pattern", response_model=SessionLedPatternOut)
def get_latest_pattern(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return the current LED pattern for a specific session."""
    from services.session_manager import session_manager
    from services.session_pattern_service import generate_pattern

    log = (
        db.query(SessionLogModel)
        .filter(
            SessionLogModel.id == session_id,
            SessionLogModel.user_id == current_user.id,
            SessionLogModel.deleted_at.is_(None),
        )
        .first()
    )
    if log is None:
        raise HTTPException(status_code=404, detail="Session not found")

    msg        = session_manager.get_latest_stream_message()
    emotion    = (msg or {}).get("emotion") or log.dominant_emotion or "calm"
    confidence = float((msg or {}).get("confidence") or log.avg_confidence or 0.5)

    pattern = generate_pattern(emotion, confidence)
    return SessionLedPatternOut(**pattern)


@router.get("/sessions/{session_id}/timeline", response_model=list[TimelineEntry])
def get_timeline(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return the ordered emotion timeline for a completed session."""
    try:
        samples = session_service.get_timeline(db, session_id, current_user.id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))

    return [
        TimelineEntry(
            timestamp=s.timestamp.isoformat(),
            detected_state=s.detected_state,
            confidence=s.confidence,
            delta=s.delta,
            theta=s.theta,
            alpha=s.alpha,
            beta=s.beta,
            gamma=s.gamma,
        )
        for s in samples
    ]
