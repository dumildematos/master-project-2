"""
services/session_pattern_service.py
-------------------------------------
Generates 8×8 LED patterns for the SENTIO Hat from a detected emotion.

Mapping:
  calm     → blue smooth wave  (Calm Waves)
  focused  → green target ring (Focus Target)
  stressed → red sparse dots   (Stress Flicker)
  relaxed  → purple fill flow  (Relax Flow)
  excited  → diagonal burst    (Excited Burst)
"""
from datetime import datetime, timezone
from typing import Any, Dict

# ── Per-emotion 8×8 grids (1 = LED on, 0 = LED off) ─────────────────────────

_GRIDS: Dict[str, list] = {
    "calm": [
        [0, 0, 1, 1, 1, 1, 0, 0],
        [0, 1, 1, 1, 1, 1, 1, 0],
        [1, 1, 1, 1, 1, 1, 1, 1],
        [1, 1, 1, 1, 1, 1, 1, 1],
        [0, 1, 1, 1, 1, 1, 1, 0],
        [0, 0, 1, 1, 1, 1, 0, 0],
        [0, 0, 0, 1, 1, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
    ],
    "focused": [
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 1, 1, 1, 1, 0, 0],
        [0, 1, 1, 0, 0, 1, 1, 0],
        [0, 1, 0, 1, 1, 0, 1, 0],
        [0, 1, 0, 1, 1, 0, 1, 0],
        [0, 1, 1, 0, 0, 1, 1, 0],
        [0, 0, 1, 1, 1, 1, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
    ],
    "stressed": [
        [1, 0, 0, 1, 0, 0, 1, 0],
        [0, 1, 0, 0, 1, 0, 0, 1],
        [0, 0, 1, 0, 0, 1, 0, 0],
        [1, 0, 0, 0, 1, 0, 0, 1],
        [0, 1, 0, 1, 0, 0, 1, 0],
        [0, 0, 1, 0, 0, 1, 0, 0],
        [1, 0, 0, 1, 0, 0, 0, 1],
        [0, 1, 0, 0, 1, 0, 1, 0],
    ],
    "relaxed": [
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 1, 1, 1, 1, 1, 1, 0],
        [1, 1, 1, 1, 1, 1, 1, 1],
        [1, 1, 1, 1, 1, 1, 1, 1],
        [0, 1, 1, 1, 1, 1, 1, 0],
        [0, 0, 1, 1, 1, 1, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
    ],
    "excited": [
        [1, 0, 0, 0, 0, 0, 0, 1],
        [0, 1, 0, 0, 0, 0, 1, 0],
        [0, 0, 1, 0, 0, 1, 0, 0],
        [0, 0, 0, 1, 1, 0, 0, 0],
        [0, 0, 0, 1, 1, 0, 0, 0],
        [0, 0, 1, 0, 0, 1, 0, 0],
        [0, 1, 0, 0, 0, 0, 1, 0],
        [1, 0, 0, 0, 0, 0, 0, 1],
    ],
}

_COLORS: Dict[str, Dict[str, str]] = {
    "calm":     {"primary": "#1A6EFF", "secondary": "#00D9FF"},
    "focused":  {"primary": "#00C48C", "secondary": "#00FF99"},
    "stressed": {"primary": "#FF3B4A", "secondary": "#FF6B35"},
    "relaxed":  {"primary": "#8A3FFC", "secondary": "#C084FC"},
    "excited":  {"primary": "#FFC107", "secondary": "#FF6B35"},
}

_MODE_NAMES: Dict[str, str] = {
    "calm":     "Calm Waves",
    "focused":  "Focus Target",
    "stressed": "Stress Flicker",
    "relaxed":  "Relax Flow",
    "excited":  "Excited Burst",
}

_FALLBACK = "calm"


def generate_pattern(emotion: str, confidence: float) -> Dict[str, Any]:
    """
    Return a full LED pattern payload for the given emotion and confidence.

    Args:
        emotion:    One of calm / focused / stressed / relaxed / excited.
        confidence: Float 0.0–1.0.  Values > 1 are normalised to [0, 1].

    Returns:
        Dict matching the SessionLedPatternOut schema.
    """
    key = emotion.lower().strip() if emotion else _FALLBACK
    if key not in _GRIDS:
        key = _FALLBACK

    # Normalise confidence to [0, 1]
    conf = max(0.0, min(1.0, confidence if confidence <= 1.0 else confidence / 100.0))

    brightness = int(40 + conf * 60)   # 40–100
    speed      = int(30 + conf * 50)   # 30–80
    colors     = _COLORS[key]

    return {
        "emotion":        key,
        "confidence":     int(conf * 100),
        "mode":           key,
        "mode_name":      _MODE_NAMES[key],
        "brightness":     brightness,
        "speed":          speed,
        "primary_color":  colors["primary"],
        "secondary_color": colors["secondary"],
        "grid":           _GRIDS[key],
        "updated_at":     datetime.now(timezone.utc).isoformat(),
    }
