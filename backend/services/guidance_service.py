"""
guidance_service.py
-------------------
Generates a short, contextual guidance sentence for the wearer using Claude AI.

Design decisions:
- NON-BLOCKING: the EEG stream loop calls get_guidance() and gets back whatever
  is currently cached — it never waits for Claude. The actual API call runs in a
  background daemon thread.
- Results are cached per (emotion, confidence_bucket). A new fetch is triggered
  only when the cache is empty or the TTL has expired.
- If ANTHROPIC_API_KEY is absent or the call fails, get_guidance() returns None
  and the caller falls back to the static guidance string from emotionMeta.
"""

import logging
import threading
import time
from typing import Optional

from config import settings

logger = logging.getLogger("sentio.guidance")

# ---------------------------------------------------------------------------
# Shared state (protected by _lock)
# ---------------------------------------------------------------------------
_lock = threading.Lock()
_cache: dict[str, dict] = {}   # cache_key → {"text": str, "ts": float}
_pending: set[str] = set()     # cache_keys currently being fetched


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


def _build_prompt(
    emotion: str,
    confidence: float,
    alpha: float,
    beta: float,
    theta: float,
    gamma: float,
    delta: float,
    mindfulness: Optional[float],
    restfulness: Optional[float],
) -> str:
    extras = ""
    if mindfulness is not None:
        extras += f"\n- Mindfulness score: {mindfulness:.2f}"
    if restfulness is not None:
        extras += f"\n- Restfulness score: {restfulness:.2f}"

    return f"""You are the AI guidance voice of Sentio — a wearable system that reads EEG brainwaves and drives LED light patterns on a garment in real time.

Current brain state detected:
- Emotion: {emotion} (confidence {confidence:.0%})
- Alpha: {alpha:.2f}  — calm, relaxed
- Beta:  {beta:.2f}  — focus, alertness
- Theta: {theta:.2f}  — creativity, drowsiness
- Gamma: {gamma:.2f}  — high cognition, excitement
- Delta: {delta:.2f}  — deep rest{extras}

Write exactly one sentence (15-20 words) spoken directly to the wearer. The sentence should:
- Acknowledge their current emotional state naturally and positively
- Hint at what the garment light is doing right now using poetic metaphors
- Feel calm, encouraging, and immersive

Use metaphors involving light, waves, colours, or natural elements to blend the emotion with the visual display.

Example: For 'calm' emotion — 'Your serene calm flows in gentle blue ripples across the fabric'

Reply with only the sentence — no quotes, no labels, no full stop at the end."""


# ---------------------------------------------------------------------------
# Background fetch
# ---------------------------------------------------------------------------

def _fetch_in_background(
    cache_key: str,
    emotion: str,
    confidence: float,
    alpha: float,
    beta: float,
    theta: float,
    gamma: float,
    delta: float,
    mindfulness: Optional[float],
    restfulness: Optional[float],
) -> None:
    """Runs in a daemon thread — calls Claude and stores the result in cache."""
    try:
        import anthropic  # lazy import

        api_key = settings.anthropic_api_key
        if not api_key:
            return

        client = anthropic.Anthropic(api_key=api_key)
        message = client.messages.create(
            model=settings.guidance_model,
            max_tokens=60,
            messages=[
                {
                    "role": "user",
                    "content": _build_prompt(
                        emotion, confidence,
                        alpha, beta, theta, gamma, delta,
                        mindfulness, restfulness,
                    ),
                }
            ],
        )
        text = message.content[0].text.strip().rstrip(".")

        with _lock:
            _cache[cache_key] = {"text": text, "ts": time.monotonic()}
            _pending.discard(cache_key)

        logger.info(
            "Claude guidance ready  emotion=%s confidence=%.0f%%  %r",
            emotion, confidence * 100, text,
        )

    except Exception as exc:
        logger.warning("Claude guidance fetch failed: %s", exc)
        with _lock:
            _pending.discard(cache_key)


# ---------------------------------------------------------------------------
# Public API — always returns immediately
# ---------------------------------------------------------------------------

def get_guidance(
    emotion: str,
    confidence: float,
    alpha: float,
    beta: float,
    theta: float,
    gamma: float,
    delta: float,
    mindfulness: Optional[float] = None,
    restfulness: Optional[float] = None,
) -> Optional[str]:
    """
    Return the latest cached Claude guidance sentence, or None.

    Never blocks — if the cache is cold a background thread is spawned to
    fetch from Claude; the caller receives None until the first result arrives
    (typically 1-3 seconds) and then the cached value on every frame until TTL.
    """
    if not settings.anthropic_api_key:
        return None

    cache_key = f"{emotion}:{_conf_bucket(confidence)}"

    with _lock:
        cached = _cache.get(cache_key)
        is_fresh = cached and (time.monotonic() - cached["ts"]) < settings.guidance_cache_ttl
        already_pending = cache_key in _pending

    # Cache hit — return immediately
    if is_fresh:
        return cached["text"]  # type: ignore[index]

    # Cache miss / stale — kick off a background fetch (once)
    if not already_pending:
        with _lock:
            _pending.add(cache_key)
        thread = threading.Thread(
            target=_fetch_in_background,
            args=(
                cache_key, emotion, confidence,
                alpha, beta, theta, gamma, delta,
                mindfulness, restfulness,
            ),
            daemon=True,
        )
        thread.start()

    # Return stale value while refreshing, or None on first call
    return cached["text"] if cached else None  # type: ignore[index]
