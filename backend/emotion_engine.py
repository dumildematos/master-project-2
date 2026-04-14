"""
AI / Emotion Inference Layer
Rule-based model mapping EEG band powers to emotional states.

Band → Emotion heuristics (Option A – recommended for real-time stability):
  - High alpha, low beta  → calm / relaxed
  - High beta, low alpha  → focused / stressed
  - High theta            → drowsy / meditative
  - Balanced              → neutral
"""

from dataclasses import dataclass


@dataclass
class EmotionResult:
    emotion: str
    confidence: float
    bands: dict[str, float]


# Emotion rules: list of (label, condition_fn, base_confidence)
_RULES = [
    ("calm",       lambda b: b["alpha"] > 0.40 and b["beta"] < 0.25,  0.85),
    ("meditative", lambda b: b["theta"] > 0.40,                        0.80),
    ("focused",    lambda b: b["beta"]  > 0.40 and b["alpha"] < 0.30,  0.80),
    ("stressed",   lambda b: b["beta"]  > 0.50,                        0.75),
    ("drowsy",     lambda b: b["theta"] > 0.35 and b["alpha"] > 0.35,  0.70),
]


def infer(bands: dict[str, float]) -> EmotionResult:
    """
    Apply rule-based inference to determine the dominant emotional state.
    Falls back to 'neutral' if no rule matches.
    """
    for label, condition, confidence in _RULES:
        try:
            if condition(bands):
                return EmotionResult(emotion=label, confidence=confidence, bands=bands)
        except KeyError:
            continue

    return EmotionResult(emotion="neutral", confidence=0.60, bands=bands)


# Guidance messages shown to the user per emotion
GUIDANCE: dict[str, str] = {
    "calm":       "You're calm. Maintain this state to deepen the flowing visuals.",
    "meditative": "Deep focus detected. Let your mind drift for dreamy patterns.",
    "focused":    "High focus! The garment sharpens and becomes structured.",
    "stressed":   "Try to relax — take a slow breath to soften the visuals.",
    "drowsy":     "Gentle state detected. Soft, slow forms are emerging.",
    "neutral":    "Keep exploring your mental state to influence the design.",
}
