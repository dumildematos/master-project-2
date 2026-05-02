"""
api/device_router.py
---------------------
Lightweight HTTP endpoint consumed by the SENTIO Hat (ESP32 / Arduino).

The hat cannot handle WebSocket + JWT auth, so this endpoint is intentionally
unauthenticated and returns only what the firmware needs:
  - current emotion + confidence
  - per-class emotion scores (for blending)
  - signal quality (0-100)
  - AI-generated LED colors (primary, secondary, accent)
  - active flag (false when no session is running)

Route: GET /api/device/emotion
"""
from fastapi import APIRouter
from pydantic import BaseModel
from typing import Dict, Optional

from services.session_manager import session_manager

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
