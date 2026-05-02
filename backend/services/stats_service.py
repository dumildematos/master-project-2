"""
services/stats_service.py
-------------------------
Dashboard summary, session history, and statistics aggregation.
"""
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy.orm import Session

from models.db_models import SessionLog

logger = logging.getLogger("sentio.stats_svc")

_MONTHS = ["Jan","Feb","Mar","Apr","May","Jun",
           "Jul","Aug","Sep","Oct","Nov","Dec"]


# ── helpers ──────────────────────────────────────────────────────────────────

def _utcnow() -> datetime:
    return datetime.now(tz=timezone.utc)


def _aware(dt: datetime) -> datetime:
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def _start_of_day(dt: datetime) -> datetime:
    return dt.replace(hour=0, minute=0, second=0, microsecond=0)


def _range_bounds(range_str: str) -> tuple[datetime, datetime]:
    now = _utcnow()
    if range_str == "day":
        start = _start_of_day(now)
    elif range_str == "month":
        start = now - timedelta(days=30)
    else:  # week (default)
        start = now - timedelta(days=7)
    return start, now


def _fmt_seconds(secs: int) -> str:
    h = secs // 3600
    m = (secs % 3600) // 60
    if h > 0:
        return f"{h}h {m}m"
    return f"{m}m" if m > 0 else "0m"


def _state_seconds(logs: list[SessionLog]) -> dict[str, int]:
    return {
        "focused":  sum(s.focus_time_seconds    or 0 for s in logs),
        "calm":     sum(s.calm_time_seconds      or 0 for s in logs),
        "relaxed":  sum(s.relaxed_time_seconds   or 0 for s in logs),
        "stressed": sum(s.stressed_time_seconds  or 0 for s in logs),
        "excited":  sum(s.excited_time_seconds   or 0 for s in logs),
    }


# ── public API ────────────────────────────────────────────────────────────────

def get_dashboard_summary(db: Session, user_id: str) -> dict:
    from services.session_manager import session_manager  # avoid circular at module level

    now = _utcnow()
    today_start = _start_of_day(now)

    today_logs: list[SessionLog] = (
        db.query(SessionLog)
        .filter(
            SessionLog.user_id == user_id,
            SessionLog.start_time >= today_start,
            SessionLog.end_time.isnot(None),
            SessionLog.deleted_at.is_(None),
        )
        .all()
    )

    state_secs = _state_seconds(today_logs)
    top_state = (
        max(state_secs, key=state_secs.get)
        if any(state_secs.values()) else "neutral"
    )

    # Live state from WebSocket frame buffer
    latest_msg = session_manager.get_latest_stream_message() or {}
    current_state      = latest_msg.get("emotion", "neutral")
    current_confidence = float(latest_msg.get("confidence", 0.0))

    # Most recent completed session
    last_session: Optional[SessionLog] = (
        db.query(SessionLog)
        .filter(
            SessionLog.user_id == user_id,
            SessionLog.end_time.isnot(None),
            SessionLog.deleted_at.is_(None),
        )
        .order_by(SessionLog.end_time.desc())
        .first()
    )

    last_summary = None
    if last_session:
        last_summary = {
            "session_id":         last_session.id,
            "title":              last_session.session_title or last_session.session_type,
            "duration_seconds":   last_session.duration_seconds,
            "dominant_state":     last_session.dominant_emotion,
            "average_confidence": last_session.avg_confidence,
            "ended_at":           _aware(last_session.end_time).isoformat()
                                  if last_session.end_time else None,
        }

    return {
        "current_state":      current_state,
        "current_confidence": current_confidence,
        "focus_time_today":   state_secs["focused"],
        "total_time_today":   sum(s.duration_seconds or 0 for s in today_logs),
        "top_state_today":    top_state,
        "sessions_today":     len(today_logs),
        "last_session":       last_summary,
    }


def get_session_history(
    db: Session,
    user_id: str,
    range_str: str = "week",
) -> list[SessionLog]:
    start, end = _range_bounds(range_str)
    return (
        db.query(SessionLog)
        .filter(
            SessionLog.user_id == user_id,
            SessionLog.start_time >= start,
            SessionLog.start_time <= end,
            SessionLog.end_time.isnot(None),
            SessionLog.deleted_at.is_(None),
        )
        .order_by(SessionLog.start_time.desc())
        .all()
    )


def get_stats(
    db: Session,
    user_id: str,
    range_str: str = "week",
) -> dict:
    start, end = _range_bounds(range_str)

    logs: list[SessionLog] = (
        db.query(SessionLog)
        .filter(
            SessionLog.user_id == user_id,
            SessionLog.start_time >= start,
            SessionLog.end_time.isnot(None),
            SessionLog.deleted_at.is_(None),
        )
        .order_by(SessionLog.start_time)
        .all()
    )

    if not logs:
        return _empty_stats(range_str)

    state_secs  = _state_seconds(logs)
    total_focus = state_secs["focused"]
    total_sess  = sum(s.duration_seconds or 0 for s in logs)
    avg_conf    = sum(s.avg_confidence or 0 for s in logs) / len(logs)

    dominant = (
        max(state_secs, key=state_secs.get)
        if any(state_secs.values()) else "neutral"
    )
    total_state = sum(state_secs.values()) or 1
    breakdown   = {k: round(v / total_state, 3) for k, v in state_secs.items()}

    return {
        "total_focus_time_seconds":   total_focus,
        "total_session_time_seconds": total_sess,
        "sessions_count":             len(logs),
        "dominant_state":             dominant,
        "average_confidence":         round(avg_conf, 3),
        "state_breakdown":            breakdown,
        "chart_data":                 _build_chart_data(logs, range_str, start),
        "focus_time_str":             _fmt_seconds(total_focus),
    }


# ── chart helpers ─────────────────────────────────────────────────────────────

def _build_chart_data(
    logs: list[SessionLog],
    range_str: str,
    period_start: datetime,
) -> list[dict]:
    if range_str == "day":
        return _hourly_chart(logs)
    elif range_str == "month":
        return _weekly_chart(logs, period_start)
    else:
        return _daily_chart(logs, period_start)


def _hourly_chart(logs: list[SessionLog]) -> list[dict]:
    """Group today's sessions into 3-hour buckets (6am–9pm)."""
    hour_buckets = [6, 9, 12, 15, 18, 21]
    labels       = ["6am", "9am", "12pm", "3pm", "6pm", "9pm"]
    data: dict[int, int] = {h: 0 for h in hour_buckets}

    for s in logs:
        hour = _aware(s.start_time).hour
        bucket = max((b for b in hour_buckets if b <= hour), default=hour_buckets[0])
        data[bucket] += s.focus_time_seconds or 0

    return [
        {"label": lbl, "value": round(data[b] / 60, 1)}
        for lbl, b in zip(labels, hour_buckets)
    ]


def _daily_chart(logs: list[SessionLog], week_start: datetime) -> list[dict]:
    """Mon–Sun for the current 7-day window."""
    labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    data   = [0] * 7

    for s in logs:
        dow = _aware(s.start_time).weekday()  # 0=Mon, 6=Sun
        if 0 <= dow < 7:
            data[dow] += s.focus_time_seconds or 0

    return [{"label": lbl, "value": round(v / 60, 1)} for lbl, v in zip(labels, data)]


def _weekly_chart(logs: list[SessionLog], month_start: datetime) -> list[dict]:
    """Wk 1–4 for the current 30-day window."""
    labels = ["Wk 1", "Wk 2", "Wk 3", "Wk 4"]
    data   = [0, 0, 0, 0]

    for s in logs:
        offset = (_aware(s.start_time) - month_start).days
        wk = min(max(offset // 7, 0), 3)
        data[wk] += s.focus_time_seconds or 0

    return [{"label": lbl, "value": round(v / 60, 1)} for lbl, v in zip(labels, data)]


def _empty_stats(range_str: str) -> dict:
    if range_str == "day":
        chart = [{"label": l, "value": 0.0}
                 for l in ["6am", "9am", "12pm", "3pm", "6pm", "9pm"]]
    elif range_str == "month":
        chart = [{"label": l, "value": 0.0}
                 for l in ["Wk 1", "Wk 2", "Wk 3", "Wk 4"]]
    else:
        chart = [{"label": l, "value": 0.0}
                 for l in ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]]
    return {
        "total_focus_time_seconds":   0,
        "total_session_time_seconds": 0,
        "sessions_count":             0,
        "dominant_state":             "neutral",
        "average_confidence":         0.0,
        "state_breakdown": {
            "focused": 0.0, "calm": 0.0, "relaxed": 0.0,
            "stressed": 0.0, "excited": 0.0,
        },
        "chart_data":    chart,
        "focus_time_str": "0m",
    }
