"""
ai_emotion_service.py
----------------------
AI-powered emotion prediction service.

Priority chain:
  1. User-specific trained model (if exists in ModelMetadata)
  2. Global trained model (user_id IS NULL in ModelMetadata)
  3. Rule-based fallback (EmotionMapper — always available)

Models are loaded once per user_id and cached in-process to avoid repeated
disk reads on the hot stream path.
"""
import logging
import os
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import numpy as np

from emotion.emotion_mapping import EmotionMapper
from models.schemas import EmotionResult, EmotionType
from services.brainwave_feature_extractor import BrainwaveFeatureExtractor, feature_extractor

logger = logging.getLogger("sentio.ai")

_LABELS: List[str] = ["calm", "focused", "relaxed", "stressed", "excited"]
_LABEL_TO_IDX: Dict[str, int] = {l: i for i, l in enumerate(_LABELS)}

# In-process model cache: user_id (or "global") → loaded sklearn estimator
_model_cache: Dict[str, object] = {}
_rule_mapper = EmotionMapper()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def predict(
    features: Dict[str, float],
    user_id: Optional[str] = None,
    baseline: Optional[Dict[str, float]] = None,
) -> EmotionResult:
    """
    Predict emotion from raw band-power features.

    Returns EmotionResult with emotion, confidence, and per-class
    emotion_scores (probability distribution over the 5 states).
    """
    rich = feature_extractor.extract(features, baseline=baseline)
    model = _load_best_model(user_id)

    if model is not None:
        return _predict_with_model(model, rich, features)

    return _predict_rule_based(features)


def invalidate_cache(user_id: Optional[str] = None) -> None:
    """Remove a model from the in-process cache (call after re-training)."""
    key = user_id or "global"
    _model_cache.pop(key, None)
    if user_id:
        _model_cache.pop("global", None)


# ---------------------------------------------------------------------------
# Model loading
# ---------------------------------------------------------------------------

def _load_best_model(user_id: Optional[str]) -> Optional[object]:
    """
    Try user model first, then global.  Uses DB to find the latest model path.
    Results are cached in _model_cache for the lifetime of the process.
    """
    if user_id:
        model = _load_model_for_key(user_id)
        if model is not None:
            return model

    return _load_model_for_key("global")


def _load_model_for_key(key: str) -> Optional[object]:
    if key in _model_cache:
        return _model_cache[key]

    path = _resolve_model_path(key)
    if path is None or not path.exists():
        return None

    try:
        import joblib
        model = joblib.load(path)
        _model_cache[key] = model
        logger.info("Loaded AI model key=%s path=%s", key, path)
        return model
    except Exception as exc:
        logger.warning("Failed to load AI model key=%s: %s", key, exc)
        return None


def _resolve_model_path(key: str) -> Optional[Path]:
    """Query DB for the latest model path for this key."""
    try:
        from database import SessionLocal
        from models.db_models import ModelMetadata

        db = SessionLocal()
        try:
            if key == "global":
                row = (
                    db.query(ModelMetadata)
                    .filter(ModelMetadata.user_id.is_(None))
                    .order_by(ModelMetadata.trained_at.desc())
                    .first()
                )
            else:
                row = (
                    db.query(ModelMetadata)
                    .filter(ModelMetadata.user_id == key)
                    .order_by(ModelMetadata.trained_at.desc())
                    .first()
                )
        finally:
            db.close()

        if row is None:
            return None

        base = Path(__file__).parent.parent / "ai_models"
        return base / row.model_path
    except Exception as exc:
        logger.debug("DB lookup for model key=%s failed: %s", key, exc)
        return None


# ---------------------------------------------------------------------------
# Prediction paths
# ---------------------------------------------------------------------------

def _predict_with_model(
    model: object,
    rich_features: Dict[str, float],
    raw_bands: Dict[str, float],
) -> EmotionResult:
    try:
        vec = np.array(
            BrainwaveFeatureExtractor.to_vector(rich_features), dtype=np.float64
        ).reshape(1, -1)

        raw_pred = model.predict(vec)[0]
        emotion_str = str(raw_pred)

        # Probability scores
        scores: Dict[str, float] = {l: 0.0 for l in _LABELS}
        if hasattr(model, "predict_proba"):
            proba = model.predict_proba(vec)[0]
            classes = list(model.classes_)
            for cls, p in zip(classes, proba):
                scores[str(cls)] = round(float(p), 4)
            confidence = float(np.max(proba))
        else:
            confidence = 0.70
            scores[emotion_str] = confidence

        try:
            emotion = EmotionType(emotion_str)
        except ValueError:
            emotion = EmotionType.calm

        return EmotionResult(
            emotion=emotion,
            confidence=round(confidence, 3),
            emotion_scores=scores,
        )
    except Exception as exc:
        logger.warning("ML prediction failed, falling back to rule-based: %s", exc)
        return _predict_rule_based(raw_bands)


def _predict_rule_based(bands: Dict[str, float]) -> EmotionResult:
    result = _rule_mapper.detect_emotion(bands)
    emotion_str = result["emotion"].value
    confidence = float(result["confidence"])
    scores = {l: 0.05 for l in _LABELS}
    scores[emotion_str] = confidence
    # Redistribute remainder evenly
    remainder = max(0.0, 1.0 - confidence) / max(len(_LABELS) - 1, 1)
    for l in _LABELS:
        if l != emotion_str:
            scores[l] = round(remainder, 4)
    scores[emotion_str] = round(confidence, 4)

    return EmotionResult(
        emotion=result["emotion"],
        confidence=round(confidence, 3),
        emotion_scores=scores,
    )
