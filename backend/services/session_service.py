"""
services/session_service.py
---------------------------
Session lifecycle: create → (sample)* → end → timeline.

save_sample_from_stream() is designed to be called from background threads
(BrainFlow / mobile-bands pipeline).  It opens its own DB session so it is
fully thread-safe.
"""
import logging
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.orm import Session

from models.db_models import BrainwaveSample, SessionLog

logger = logging.getLogger("sentio.session_svc")


# ── helpers ──────────────────────────────────────────────────────────────────

def _utcnow() -> datetime:
    return datetime.now(tz=timezone.utc)


def _aware(dt: datetime) -> datetime:
    """Attach UTC tz-info to a naïve datetime (SQLite stores naïve)."""
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


# ── public API ────────────────────────────────────────────────────────────────

def create_session(
    db: Session,
    user_id: str,
    title: Optional[str] = None,
) -> SessionLog:
    """
    Create a new DB session record and register it as the active recording
    target in session_manager so the stream pipeline persists samples.
    """
    from services.session_manager import session_manager  # local to avoid circular

    log = SessionLog(
        user_id=user_id,
        session_title=title or "Session",
        session_type="monitoring",
        start_time=_utcnow(),
    )
    db.add(log)
    db.commit()
    db.refresh(log)

    session_manager.set_db_session_id(log.id)
    logger.info("DB session created id=%s user=%s title=%s", log.id, user_id, title)
    return log


def save_sample_from_stream(
    db_session_id: str,
    features: dict,
    emotion: str,
    confidence: float,
) -> None:
    """
    Persist one processed EEG snapshot.
    Creates its own DB session — safe to call from any thread.
    """
    from database import SessionLocal

    alpha = float(features.get("alpha", 0) or 0)
    beta  = float(features.get("beta",  0) or 0)
    theta = float(features.get("theta", 0) or 0)

    db = SessionLocal()
    try:
        sample = BrainwaveSample(
            session_id=db_session_id,
            timestamp=_utcnow(),
            delta=float(features.get("delta", 0) or 0),
            theta=theta,
            alpha=alpha,
            beta=beta,
            gamma=float(features.get("gamma", 0) or 0),
            attention_score=min(1.0, beta / max(alpha, 0.01)),
            relaxation_score=alpha,
            stress_score=min(1.0, beta / max(alpha + theta, 0.01)),
            detected_state=emotion,
            confidence=confidence,
        )
        db.add(sample)
        db.commit()
    except Exception:
        logger.exception("Failed to save brainwave sample session_id=%s", db_session_id)
        db.rollback()
    finally:
        db.close()


def end_session(
    db: Session,
    session_id: str,
    user_id: str,
) -> SessionLog:
    """
    Compute summary statistics from all BrainwaveSamples, persist them onto
    the SessionLog, and deregister the active DB session from session_manager.
    """
    from services.session_manager import session_manager

    log = (
        db.query(SessionLog)
        .filter(SessionLog.id == session_id, SessionLog.user_id == user_id)
        .first()
    )
    if log is None:
        raise ValueError(f"Session {session_id} not found for user {user_id}")

    samples: list[BrainwaveSample] = (
        db.query(BrainwaveSample)
        .filter(BrainwaveSample.session_id == session_id)
        .order_by(BrainwaveSample.timestamp)
        .all()
    )

    now = _utcnow()
    start = _aware(log.start_time)
    duration_s = max(0, int((now - start).total_seconds()))

    # Aggregate from samples
    emotion_counts: dict[str, int] = {}
    total_conf = total_alpha = total_beta = total_theta = total_gamma = 0.0

    for s in samples:
        state = s.detected_state or "neutral"
        emotion_counts[state] = emotion_counts.get(state, 0) + 1
        total_conf  += s.confidence or 0
        total_alpha += s.alpha      or 0
        total_beta  += s.beta       or 0
        total_theta += s.theta      or 0
        total_gamma += s.gamma      or 0

    n = len(samples) or 1
    seconds_per_sample = duration_s / n

    dominant = (
        max(emotion_counts, key=emotion_counts.get)
        if emotion_counts else "neutral"
    )

    log.end_time              = now
    log.duration_seconds      = duration_s
    log.dominant_emotion      = dominant
    log.avg_confidence        = round(total_conf  / n, 3)
    log.avg_alpha             = round(total_alpha / n, 4)
    log.avg_beta              = round(total_beta  / n, 4)
    log.avg_theta             = round(total_theta / n, 4)
    log.avg_gamma             = round(total_gamma / n, 4)
    log.focus_time_seconds    = round(emotion_counts.get("focused",  0) * seconds_per_sample)
    log.calm_time_seconds     = round(emotion_counts.get("calm",     0) * seconds_per_sample)
    log.relaxed_time_seconds  = round(emotion_counts.get("relaxed",  0) * seconds_per_sample)
    log.stressed_time_seconds = round(emotion_counts.get("stressed", 0) * seconds_per_sample)
    log.excited_time_seconds  = round(emotion_counts.get("excited",  0) * seconds_per_sample)

    db.commit()
    db.refresh(log)

    session_manager.clear_db_session_id()
    logger.info(
        "DB session ended id=%s duration=%ss dominant=%s samples=%s",
        session_id, duration_s, dominant, len(samples),
    )
    return log


def stop_session(
    db: Session,
    session_id: str,
    user_id: str,
) -> SessionLog:
    """
    User-initiated stop: compute summary metrics, set status='stopped', clear pipeline.
    Reuses end_session logic but marks status differently and tolerates already-ended sessions.
    """
    from services.session_manager import session_manager

    log = (
        db.query(SessionLog)
        .filter(
            SessionLog.id == session_id,
            SessionLog.user_id == user_id,
            SessionLog.deleted_at.is_(None),
        )
        .first()
    )
    if log is None:
        raise ValueError(f"Session {session_id} not found for user {user_id}")

    if log.end_time is not None:
        # Already ended — just return it
        return log

    samples: list[BrainwaveSample] = (
        db.query(BrainwaveSample)
        .filter(BrainwaveSample.session_id == session_id)
        .order_by(BrainwaveSample.timestamp)
        .all()
    )

    now = _utcnow()
    start = _aware(log.start_time)
    duration_s = max(0, int((now - start).total_seconds()))

    emotion_counts: dict[str, int] = {}
    total_conf = total_alpha = total_beta = total_theta = total_gamma = 0.0

    for s in samples:
        state = s.detected_state or "neutral"
        emotion_counts[state] = emotion_counts.get(state, 0) + 1
        total_conf  += s.confidence or 0
        total_alpha += s.alpha      or 0
        total_beta  += s.beta       or 0
        total_theta += s.theta      or 0
        total_gamma += s.gamma      or 0

    n = len(samples) or 1
    seconds_per_sample = duration_s / n

    dominant = (
        max(emotion_counts, key=emotion_counts.get)
        if emotion_counts else "neutral"
    )

    log.end_time              = now
    log.duration_seconds      = duration_s
    log.status                = "stopped"
    log.dominant_emotion      = dominant
    log.avg_confidence        = round(total_conf  / n, 3)
    log.avg_alpha             = round(total_alpha / n, 4)
    log.avg_beta              = round(total_beta  / n, 4)
    log.avg_theta             = round(total_theta / n, 4)
    log.avg_gamma             = round(total_gamma / n, 4)
    log.focus_time_seconds    = round(emotion_counts.get("focused",  0) * seconds_per_sample)
    log.calm_time_seconds     = round(emotion_counts.get("calm",     0) * seconds_per_sample)
    log.relaxed_time_seconds  = round(emotion_counts.get("relaxed",  0) * seconds_per_sample)
    log.stressed_time_seconds = round(emotion_counts.get("stressed", 0) * seconds_per_sample)
    log.excited_time_seconds  = round(emotion_counts.get("excited",  0) * seconds_per_sample)

    db.commit()
    db.refresh(log)

    if session_manager.get_db_session_id() == session_id:
        session_manager.clear_db_session_id()

    logger.info(
        "DB session stopped id=%s duration=%ss dominant=%s samples=%s",
        session_id, duration_s, dominant, len(samples),
    )
    return log


def delete_session(
    db: Session,
    session_id: str,
    user_id: str,
) -> None:
    """
    Soft-delete a session: set deleted_at timestamp and status='deleted'.
    If the session is still active, stop it first.
    """
    from services.session_manager import session_manager

    log = (
        db.query(SessionLog)
        .filter(
            SessionLog.id == session_id,
            SessionLog.user_id == user_id,
            SessionLog.deleted_at.is_(None),
        )
        .first()
    )
    if log is None:
        raise ValueError(f"Session {session_id} not found for user {user_id}")

    if log.end_time is None:
        if session_manager.get_db_session_id() == session_id:
            session_manager.clear_db_session_id()
        log.end_time = _utcnow()

    log.deleted_at = _utcnow()
    log.status     = "deleted"
    db.commit()
    logger.info("DB session soft-deleted id=%s user=%s", session_id, user_id)


def get_timeline(
    db: Session,
    session_id: str,
    user_id: str,
) -> list[BrainwaveSample]:
    """Return all ordered brainwave samples for a session (ownership check included)."""
    log = (
        db.query(SessionLog)
        .filter(SessionLog.id == session_id, SessionLog.user_id == user_id)
        .first()
    )
    if log is None:
        raise ValueError(f"Session {session_id} not found")

    return (
        db.query(BrainwaveSample)
        .filter(BrainwaveSample.session_id == session_id)
        .order_by(BrainwaveSample.timestamp)
        .all()
    )
