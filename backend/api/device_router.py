"""
api/device_router.py
---------------------
Lightweight HTTP endpoints consumed by the SENTIO Hat (Arduino) and Flutter app.

All endpoints are intentionally unauthenticated — the Arduino firmware cannot
handle JWT auth.

Routes:
  GET  /api/device/emotion  — current emotion state for autonomous hat rendering
  POST /api/device/pattern  — Flutter pushes a preview pattern for the hat to display
  GET  /api/device/pattern  — Arduino polls for the latest pushed pattern
"""
from fastapi import APIRouter
from pydantic import BaseModel
from typing import Any, Dict, List, Optional

from services.session_manager import session_manager

# In-memory store for the last pattern pushed from the mobile app.
# The Arduino polls GET /api/device/pattern and renders whatever is here.
_pending_pattern: Optional[Dict[str, Any]] = None

router = APIRouter()

_DEFAULT_COLORS: Dict[str, Dict[str, str]] = {
    "calm":     {"primary": "#1A6EFF", "secondary": "#00D9FF", "accent": "#FFFFFF"},
    "focused":  {"primary": "#00C48C", "secondary": "#00FF99", "accent": "#AAFFDD"},
    "relaxed":  {"primary": "#8A3FFC", "secondary": "#C084FC", "accent": "#E9D5FF"},
    "stressed": {"primary": "#FF3B4A", "secondary": "#FF6B35", "accent": "#FFCC00"},
    "excited":  {"primary": "#FFC107", "secondary": "#FF6B35", "accent": "#FFFFFF"},
}


class DeviceEmotionOut(BaseModel):
    active:        bool
    emotion:       str
    confidence:    float
    signal_quality: float
    emotion_scores: Dict[str, float]
    primary_color:  str
    secondary_color: str
    accent_color:   str
    pattern_type:   Optional[str]


@router.get("/device/emotion", response_model=DeviceEmotionOut)
def get_device_emotion():
    """
    Return the current emotion state for the SENTIO Hat firmware.

    When no session is active the hat receives active=false and should
    display its idle animation.
    """
    msg = session_manager.get_latest_stream_message()

    if msg is None or not msg.get("active"):
        return DeviceEmotionOut(
            active         = False,
            emotion        = "calm",
            confidence     = 0.0,
            signal_quality = 0.0,
            emotion_scores = {e: 0.0 for e in _DEFAULT_COLORS},
            primary_color  = "#0D2137",
            secondary_color= "#0D2137",
            accent_color   = "#1A3350",
            pattern_type   = None,
        )

    emotion   = str(msg.get("emotion", "calm"))
    confidence = float(msg.get("confidence", 0.5))
    signal_q   = float(msg.get("signal_quality", 50.0))

    # Per-class scores from AI model (falls back to simple distribution)
    raw_scores = msg.get("emotion_scores") or {}
    scores = {e: float(raw_scores.get(e, 0.0)) for e in _DEFAULT_COLORS}
    if not any(scores.values()):
        scores[emotion] = confidence

    # Colors: prefer AI-generated palette, fall back to emotion defaults
    ai_pattern   = msg.get("ai_pattern") or {}
    defaults     = _DEFAULT_COLORS.get(emotion, _DEFAULT_COLORS["calm"])
    primary_hex  = str(ai_pattern.get("primary",   defaults["primary"]))
    secondary_hex= str(ai_pattern.get("secondary", defaults["secondary"]))
    accent_hex   = str(ai_pattern.get("accent",    defaults["accent"]))

    return DeviceEmotionOut(
        active         = True,
        emotion        = emotion,
        confidence     = round(confidence, 3),
        signal_quality = round(signal_q, 1),
        emotion_scores = scores,
        primary_color  = primary_hex,
        secondary_color= secondary_hex,
        accent_color   = accent_hex,
        pattern_type   = msg.get("user_pattern_override") or msg.get("pattern_type"),
    )


# ---------------------------------------------------------------------------
# Pattern preview endpoints
# ---------------------------------------------------------------------------

class PatternPayload(BaseModel):
    mode:       str
    brightness: int
    speed:      int
    colors:     List[str]
    pattern:    List[List[int]]
    rgb_grid:   Optional[List[List[str]]] = None   # 8×8 actual hex colors per pixel


class PatternOut(BaseModel):
    available:  bool
    mode:       Optional[str]
    brightness: Optional[int]
    speed:      Optional[int]
    colors:     Optional[List[str]]
    pattern:    Optional[List[List[int]]]
    rgb_grid:   Optional[List[List[str]]] = None


@router.post("/device/pattern", status_code=200)
def push_device_pattern(payload: PatternPayload):
    """
    Flutter posts the pattern to preview here.
    The Arduino polls GET /api/device/pattern and renders it immediately.
    """
    global _pending_pattern
    _pending_pattern = payload.model_dump()
    return {"ok": True}


@router.get("/device/pattern", response_model=PatternOut)
def get_device_pattern():
    """
    Arduino polls this endpoint to get the latest pattern pushed from Flutter.
    Returns available=false when nothing has been pushed yet.
    """
    if _pending_pattern is None:
        return PatternOut(
            available=False,
            mode=None, brightness=None, speed=None,
            colors=None, pattern=None,
        )
    return PatternOut(available=True, **_pending_pattern)
