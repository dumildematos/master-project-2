"""
services/claude_led_service.py
-------------------------------
ClaudeLedPatternService — generates SENTIO Hat LED patterns via Claude AI.
Falls back to keyword-matched presets if Claude is unavailable or returns
invalid output.
"""
import json
import logging
import re
from typing import Any, Dict, List, Tuple

from config import settings

logger = logging.getLogger("sentio.claude_led")

_ALLOWED_MODES: set = {"static", "breathing", "pulse", "wave", "flicker", "burst", "spiral"}
_HEX_RE = re.compile(r'^#[0-9A-Fa-f]{6}$')

# ── Fallback grids per emotion ────────────────────────────────────────────────

_FALLBACK_PATTERNS: Dict[str, Dict[str, Any]] = {
    "calm": {
        "name": "Calm Ocean Waves",
        "mode": "breathing",
        "primaryColor": "#1A6EFF",
        "secondaryColor": "#00D9FF",
        "brightness": 70,
        "speed": 40,
        "grid": [
            [0, 0, 1, 1, 1, 1, 0, 0],
            [0, 1, 1, 1, 1, 1, 1, 0],
            [1, 1, 1, 1, 1, 1, 1, 1],
            [1, 1, 1, 1, 1, 1, 1, 1],
            [0, 1, 1, 1, 1, 1, 1, 0],
            [0, 0, 1, 1, 1, 1, 0, 0],
            [0, 0, 0, 1, 1, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
        ],
        "description": "A smooth blue wave pattern for calm emotional feedback.",
    },
    "focused": {
        "name": "Focus Target",
        "mode": "pulse",
        "primaryColor": "#00C48C",
        "secondaryColor": "#00FF99",
        "brightness": 80,
        "speed": 60,
        "grid": [
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 1, 1, 1, 1, 0, 0],
            [0, 1, 1, 0, 0, 1, 1, 0],
            [0, 1, 0, 1, 1, 0, 1, 0],
            [0, 1, 0, 1, 1, 0, 1, 0],
            [0, 1, 1, 0, 0, 1, 1, 0],
            [0, 0, 1, 1, 1, 1, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
        ],
        "description": "A centered green target ring for focused state feedback.",
    },
    "stressed": {
        "name": "Stress Flicker",
        "mode": "flicker",
        "primaryColor": "#FF3B4A",
        "secondaryColor": "#FF6B35",
        "brightness": 90,
        "speed": 80,
        "grid": [
            [1, 0, 0, 1, 0, 0, 1, 0],
            [0, 1, 0, 0, 1, 0, 0, 1],
            [0, 0, 1, 0, 0, 1, 0, 0],
            [1, 0, 0, 0, 1, 0, 0, 1],
            [0, 1, 0, 1, 0, 0, 1, 0],
            [0, 0, 1, 0, 0, 1, 0, 0],
            [1, 0, 0, 1, 0, 0, 0, 1],
            [0, 1, 0, 0, 1, 0, 1, 0],
        ],
        "description": "Chaotic red flicker pattern for stressed state feedback.",
    },
    "relaxed": {
        "name": "Relax Flow",
        "mode": "breathing",
        "primaryColor": "#8A3FFC",
        "secondaryColor": "#C084FC",
        "brightness": 60,
        "speed": 30,
        "grid": [
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 1, 1, 1, 1, 1, 1, 0],
            [1, 1, 1, 1, 1, 1, 1, 1],
            [1, 1, 1, 1, 1, 1, 1, 1],
            [0, 1, 1, 1, 1, 1, 1, 0],
            [0, 0, 1, 1, 1, 1, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
        ],
        "description": "A gentle purple fill flow for relaxed emotional feedback.",
    },
    "excited": {
        "name": "Excited Burst",
        "mode": "burst",
        "primaryColor": "#FFC107",
        "secondaryColor": "#FF6B35",
        "brightness": 100,
        "speed": 90,
        "grid": [
            [1, 0, 0, 0, 0, 0, 0, 1],
            [0, 1, 0, 0, 0, 0, 1, 0],
            [0, 0, 1, 0, 0, 1, 0, 0],
            [0, 0, 0, 1, 1, 0, 0, 0],
            [0, 0, 0, 1, 1, 0, 0, 0],
            [0, 0, 1, 0, 0, 1, 0, 0],
            [0, 1, 0, 0, 0, 0, 1, 0],
            [1, 0, 0, 0, 0, 0, 0, 1],
        ],
        "description": "A diagonal yellow burst for excited emotional feedback.",
    },
}

_KEYWORD_MAP: List[Tuple[List[str], str]] = [
    (["calm", "ocean", "wave", "peace", "gentle", "serene", "smooth", "blue"], "calm"),
    (["focus", "target", "center", "laser", "sharp", "concentrate", "green"], "focused"),
    (["stress", "chaos", "panic", "anxious", "frantic", "worry", "red", "chaotic"], "stressed"),
    (["relax", "purple", "flow", "soft", "slow", "quiet", "spiral"], "relaxed"),
    (["excit", "burst", "energy", "wild", "yellow", "orange", "fire", "explosion"], "excited"),
]

_SYSTEM_PROMPT = """\
You are an LED pattern generator for SENTIO, an EEG-driven emotion feedback hat.

Generate one 8x8 WS2812 LED matrix pattern.

Rules:
- Output ONLY valid JSON. No markdown. No code fences. No text outside the JSON object.
- Grid must be exactly 8 rows, each row exactly 8 integers.
- Values must be 0 or 1 only.
- Use SENTIO emotional design language:
  - calm: blue smooth waves
  - focused: green centered target
  - stressed: red chaotic flicker
  - relaxed: purple flowing gentle
  - excited: yellow/orange diagonal burst
- Colors must be HEX strings in #RRGGBB format.
- Mode must be exactly one of: static | breathing | pulse | wave | flicker | burst | spiral
- Pattern must be readable on an 8x8 LED matrix (avoid overly complex shapes).

Return ONLY this JSON object:
{
  "name": "<short human-readable pattern name>",
  "mode": "<static|breathing|pulse|wave|flicker|burst|spiral>",
  "primaryColor": "#RRGGBB",
  "secondaryColor": "#RRGGBB",
  "brightness": <integer 0-100>,
  "speed": <integer 0-100>,
  "grid": [[8 integers of 0 or 1], ... 8 rows total],
  "description": "<1-2 sentence description>"
}\
"""


class ClaudeLedPatternService:
    """Generates SENTIO Hat LED patterns via Claude AI with validation and fallback."""

    def __init__(self) -> None:
        self._client = None

    def _get_client(self):
        if self._client is not None:
            return self._client
        import anthropic
        api_key = settings.anthropic_api_key
        if not api_key:
            raise RuntimeError("ANTHROPIC_API_KEY not configured in backend/.env")
        self._client = anthropic.Anthropic(api_key=api_key)
        return self._client

    # ── Public API ────────────────────────────────────────────────────────────

    def generate_pattern(
        self,
        user_prompt: str,
        brightness: int,
        speed: int,
    ) -> Dict[str, Any]:
        """
        Generate an 8×8 LED pattern from a free-text prompt via Claude.
        Falls back to a keyword-matched preset if Claude fails or is not configured.
        """
        clean = _sanitize_prompt(user_prompt)
        try:
            raw = self._call_claude(clean, brightness, speed)
            data = _parse_response(raw)
            return self.validate_pattern(data, brightness, speed)
        except Exception as exc:
            logger.warning("Claude LED generation failed (%s) — using fallback", exc)
            return self.fallback_pattern(clean, brightness, speed)

    def validate_pattern(
        self,
        data: Dict[str, Any],
        brightness: int = -1,
        speed: int = -1,
    ) -> Dict[str, Any]:
        """Validate and repair a pattern dict. Raises ValueError if irrecoverable."""
        # grid
        grid = data.get("grid")
        if not isinstance(grid, list) or len(grid) != 8:
            raise ValueError("grid must have exactly 8 rows")
        repaired: List[List[int]] = []
        for row in grid:
            if not isinstance(row, list) or len(row) != 8:
                raise ValueError("each grid row must have exactly 8 values")
            repaired.append([1 if v else 0 for v in row])
        data["grid"] = repaired

        # colors
        for key in ("primaryColor", "secondaryColor"):
            if not _HEX_RE.match(str(data.get(key, ""))):
                data[key] = "#00D9FF"

        # mode
        if data.get("mode") not in _ALLOWED_MODES:
            data["mode"] = "breathing"

        # brightness / speed — caller values take precedence when provided
        data["brightness"] = brightness if brightness >= 0 else int(max(0, min(100, data.get("brightness", 70))))
        data["speed"]      = speed      if speed      >= 0 else int(max(0, min(100, data.get("speed",      60))))

        # strings
        data.setdefault("name", "Generated Pattern")
        data.setdefault("description", "AI-generated LED pattern.")
        data["name"]        = str(data["name"])[:80]
        data["description"] = str(data["description"])[:300]

        return data

    def fallback_pattern(
        self,
        user_prompt: str,
        brightness: int,
        speed: int,
    ) -> Dict[str, Any]:
        """Return a keyword-matched preset with the requested brightness/speed."""
        key  = _detect_emotion(user_prompt)
        base = dict(_FALLBACK_PATTERNS[key])
        base["brightness"] = brightness
        base["speed"]      = speed
        base["grid"]       = [list(row) for row in base["grid"]]
        return base

    # ── Private ───────────────────────────────────────────────────────────────

    def _call_claude(self, user_prompt: str, brightness: int, speed: int) -> str:
        client = self._get_client()
        user_content = (
            f"USER PROMPT:\n{user_prompt}\n\n"
            f"Brightness: {brightness}\n"
            f"Speed: {speed}"
        )
        message = client.messages.create(
            model=settings.guidance_model,
            max_tokens=1024,
            system=_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_content}],
        )
        return message.content[0].text


# ── Module-level helpers ──────────────────────────────────────────────────────

def _sanitize_prompt(prompt: str) -> str:
    """Strip injection attempts and enforce 300-character limit."""
    clean = prompt.strip()[:300]
    # Remove characters that could break JSON encoding or inject instructions
    clean = re.sub(r'[{}"\\]', '', clean)
    # Strip attempts to override system instructions
    clean = re.sub(
        r'(ignore|override|forget|disregard|system|prompt|instruction)',
        '', clean, flags=re.IGNORECASE,
    )
    return clean.strip()


def _parse_response(raw: str) -> Dict[str, Any]:
    """Extract and parse the JSON object from Claude's response."""
    text = raw.strip()
    # Strip markdown code fences if present
    text = re.sub(r'^```[a-zA-Z]*\n?', '', text)
    text = re.sub(r'```\s*$', '', text)
    start = text.find('{')
    end   = text.rfind('}')
    if start == -1 or end == -1:
        raise ValueError("No JSON object found in Claude response")
    return json.loads(text[start:end + 1])


def _detect_emotion(prompt: str) -> str:
    lower = prompt.lower()
    for keywords, emotion in _KEYWORD_MAP:
        if any(kw in lower for kw in keywords):
            return emotion
    return "calm"


# Singleton
claude_led_service = ClaudeLedPatternService()
