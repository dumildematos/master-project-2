"""
pattern_service.py
------------------
Uses Claude AI to generate a fully-defined LED pattern for each EEG brain state:
  - pattern_type  : which animation to run  (fluid / geometric / pulse / stars)
  - primary/secondary/accent/shadow : four hex colours that express the emotion
  - speed         : animation playback rate  (0 = very slow, 1 = very fast)
  - complexity    : visual intricacy          (0 = simple,   1 = dense)
  - intensity     : overall brightness/vividness

Design decisions (mirrors guidance_service.py):
- NON-BLOCKING: get_ai_pattern() always returns immediately.  The actual Claude
  API call runs in a background daemon thread.
- Results are cached per (emotion, confidence_bucket).  A new fetch is only
  triggered when the cache is empty or the TTL has expired.
- Falls back to None when ANTHROPIC_API_KEY is absent or the first frame
  arrives before Claude has responded.  stream_service.py omits the ai_pattern
  field in that case so the Arduino uses its own static palette/pattern logic.
"""

import json
import logging
import threading
import time
from typing import Optional

from config import settings

logger = logging.getLogger("sentio.pattern")

# ---------------------------------------------------------------------------
# Shared state (protected by _lock)
# ---------------------------------------------------------------------------
_lock:    threading.Lock        = threading.Lock()
_cache:   dict[str, dict]       = {}   # cache_key → {"pattern": dict, "ts": float}
_pending: set[str]              = set()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _conf_bucket(confidence: float) -> str:
    """Coarsely bucket confidence to reduce unnecessary cache misses."""
    if confidence < 0.45:
        return "low"
    if confidence < 0.72:
        return "medium"
    return "high"


_PROMPT_TEMPLATE = """\
You are the visual AI for Sentio — a wearable garment with 300 WS2812B RGB LEDs \
driven in real-time by EEG brainwave data.

Current brain state detected:
- Emotion  : {emotion} (confidence {confidence:.0%})
- Alpha    : {alpha:.2f}  (calm / relaxed)
- Beta     : {beta:.2f}  (focus / alertness)
- Theta    : {theta:.2f}  (creativity / drowsiness)
- Gamma    : {gamma:.2f}  (high cognition / excitement)
- Delta    : {delta:.2f}  (deep rest)

Choose the LED pattern and colour palette that best expresses this brain state \
and makes the garment feel alive and emotionally resonant.

Reply with ONLY valid JSON — no markdown, no extra keys:
{{
  "pattern_type": "fluid|geometric|pulse|stars",
  "primary":   "#RRGGBB",
  "secondary": "#RRGGBB",
  "accent":    "#RRGGBB",
  "shadow":    "#RRGGBB",
  "speed":      0.0,
  "complexity": 0.0,
  "intensity":  0.0
}}

Pattern guide:
  fluid     — slow flowing sine-wave plasma  → calm, relaxed, meditative states
  geometric — rotating concentric rings      → focused, analytical, alert states
  pulse     — expanding cross / ring bursts  → excited, stressed, high-arousal states
  stars     — twinkling constellation field  → neutral, creative, dreamy states

Parameter guide (all values 0.0 – 1.0):
  speed      : animation playback speed  (0 = very slow,   1 = very fast)
  complexity : visual intricacy          (0 = simple,       1 = dense / intricate)
  intensity  : overall brightness       (0 = dim / subtle, 1 = vivid / punchy)

Colour guide:
  primary   : dominant colour — the emotion's main hue, saturated
  secondary : complementary tone — lighter or hue-shifted
  accent    : highlight — bright spark visible at animation peaks
  shadow    : deep background — very dark, near-black, tinted toward the emotion

Make the four colours harmonious, emotionally expressive, and beautiful on fabric.\
"""


def _build_prompt(
    emotion: str,
    confidence: float,
    alpha: float,
    beta: float,
    theta: float,
    gamma: float,
    delta: float,
) -> str:
    return _PROMPT_TEMPLATE.format(
        emotion=emotion, confidence=confidence,
        alpha=alpha, beta=beta, theta=theta, gamma=gamma, delta=delta,
    )


# ---------------------------------------------------------------------------
# Background fetch
# ---------------------------------------------------------------------------

_REQUIRED_KEYS = {"pattern_type", "primary", "secondary", "accent", "shadow",
                  "speed", "complexity", "intensity"}


def _fetch_in_background(
    cache_key: str,
    emotion: str,
    confidence: float,
    alpha: float,
    beta: float,
    theta: float,
    gamma: float,
    delta: float,
) -> None:
    """Runs in a daemon thread — calls Claude and stores the pattern in cache."""
    try:
        import anthropic  # lazy import — only when key is present

        api_key = settings.anthropic_api_key
        if not api_key:
            return

        client = anthropic.Anthropic(api_key=api_key)
        message = client.messages.create(
            model=settings.guidance_model,
            max_tokens=256,
            messages=[{
                "role": "user",
                "content": _build_prompt(
                    emotion, confidence, alpha, beta, theta, gamma, delta
                ),
            }],
        )
        raw = message.content[0].text.strip()

        # Strip markdown code fences if the model wraps the JSON
        if raw.startswith("```"):
            parts = raw.split("```")
            raw = parts[1] if len(parts) > 1 else raw
            if raw.lower().startswith("json"):
                raw = raw[4:]
        raw = raw.strip()

        pattern: dict = json.loads(raw)

        missing = _REQUIRED_KEYS - pattern.keys()
        if missing:
            raise ValueError(f"Claude pattern response missing keys: {missing}")

        # Validate / clamp numeric fields
        for key in ("speed", "complexity", "intensity"):
            pattern[key] = round(max(0.0, min(1.0, float(pattern[key]))), 3)

        # Validate pattern_type is one of the known values
        if pattern["pattern_type"] not in ("fluid", "geometric", "pulse", "stars"):
            logger.warning(
                "AI pattern returned unknown pattern_type=%r — defaulting to 'fluid'",
                pattern["pattern_type"],
            )
            pattern["pattern_type"] = "fluid"

        with _lock:
            _cache[cache_key] = {"pattern": pattern, "ts": time.monotonic()}
            _pending.discard(cache_key)

        logger.info(
            "AI pattern ready  emotion=%s  type=%-9s  speed=%.2f  complexity=%.2f  "
            "primary=%s  secondary=%s",
            emotion,
            pattern["pattern_type"],
            pattern["speed"],
            pattern["complexity"],
            pattern["primary"],
            pattern["secondary"],
        )

    except Exception as exc:
        logger.warning("AI pattern fetch failed: %s", exc)
        with _lock:
            _pending.discard(cache_key)


# ---------------------------------------------------------------------------
# Public API — always returns immediately
# ---------------------------------------------------------------------------

def get_ai_pattern(
    emotion: str,
    confidence: float,
    alpha: float,
    beta: float,
    theta: float,
    gamma: float,
    delta: float,
) -> Optional[dict]:
    """
    Return the latest cached AI pattern dict, or None.

    The dict contains:
      pattern_type  : str   "fluid" | "geometric" | "pulse" | "stars"
      primary       : str   "#RRGGBB"
      secondary     : str   "#RRGGBB"
      accent        : str   "#RRGGBB"
      shadow        : str   "#RRGGBB"
      speed         : float 0.0–1.0
      complexity    : float 0.0–1.0
      intensity     : float 0.0–1.0

    Never blocks — spawns a background thread on cache miss.
    Returns None until the first result arrives (typically 1-3 s).
    Returns the stale cached value while a background refresh is in flight.
    """
    if not settings.anthropic_api_key:
        return None

    cache_key = f"pattern:{emotion}:{_conf_bucket(confidence)}"

    with _lock:
        cached          = _cache.get(cache_key)
        is_fresh        = cached and (time.monotonic() - cached["ts"]) < settings.pattern_cache_ttl
        already_pending = cache_key in _pending

    if is_fresh:
        return cached["pattern"]  # type: ignore[index]

    if not already_pending:
        with _lock:
            _pending.add(cache_key)
        threading.Thread(
            target=_fetch_in_background,
            args=(cache_key, emotion, confidence, alpha, beta, theta, gamma, delta),
            daemon=True,
        ).start()

    # Return stale value while refreshing, or None on very first call
    return cached["pattern"] if cached else None  # type: ignore[index]
