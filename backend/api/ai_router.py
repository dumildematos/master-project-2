"""
api/ai_router.py
-----------------
AI emotion detection endpoints.

Routes
------
POST /ai/predict      — predict emotion from band powers (no session required)
POST /ai/label        — submit user-corrected emotion label (feedback loop)
POST /ai/train        — trigger model training for current user
POST /ai/calibrate    — store EEG baseline from calibration session
GET  /ai/status       — model info for current user
"""
import logging
from datetime import datetime
from typing import Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from api.auth import get_current_user
from database import get_db
from models.db_models import EmotionLabel, ModelMetadata, User, UserBaseline
import services.ai_emotion_service as ai_svc
import services.model_training_service as train_svc
from services.claude_led_service import claude_led_service

logger = logging.getLogger("sentio.ai")
router = APIRouter()

_VALID_EMOTIONS = {"calm", "focused", "relaxed", "stressed", "excited"}


# ---------------------------------------------------------------------------
# Pydantic I/O schemas
# ---------------------------------------------------------------------------

class PredictIn(BaseModel):
    alpha: float = Field(..., ge=0.0, le=1.0)
    beta:  float = Field(..., ge=0.0, le=1.0)
    theta: float = Field(..., ge=0.0, le=1.0)
    gamma: float = Field(..., ge=0.0, le=1.0)
    delta: float = Field(..., ge=0.0, le=1.0)


class PredictOut(BaseModel):
    emotion:    str
    confidence: float
    scores:     Dict[str, float]
    model_used: str  # "ai_user" | "ai_global" | "rule_based"


class LabelIn(BaseModel):
    label:      str = Field(..., description="Correct emotion: calm|focused|relaxed|stressed|excited")
    session_id: Optional[str] = None
    # Band powers at the moment of labelling (optional — used for richer training data)
    alpha: Optional[float] = None
    beta:  Optional[float] = None
    theta: Optional[float] = None
    gamma: Optional[float] = None
    delta: Optional[float] = None


class LabelOut(BaseModel):
    id:         int
    label:      str
    n_labels:   int
    auto_train: bool


class TrainOut(BaseModel):
    model_type: str
    accuracy:   float
    n_samples:  int
    model_path: str
    trained_at: str


class CalibrationStepIn(BaseModel):
    step:   str   # "neutral" | "focus" | "relax"
    alpha:  float
    beta:   float
    theta:  float
    gamma:  float
    delta:  float
    duration_seconds: int


class CalibrateIn(BaseModel):
    steps: List[CalibrationStepIn]


class CalibrateOut(BaseModel):
    alpha_mean: float
    beta_mean:  float
    theta_mean: float
    message:    str


class AiStatusOut(BaseModel):
    has_user_model:   bool
    has_global_model: bool
    user_model_accuracy:   Optional[float]
    global_model_accuracy: Optional[float]
    n_user_labels:    int
    labels_until_train: int


class LedPatternIn(BaseModel):
    prompt:     str = Field(..., min_length=1, max_length=300)
    brightness: int = Field(default=80, ge=0, le=100)
    speed:      int = Field(default=60, ge=0, le=100)

class LedPatternOut(BaseModel):
    name:           str
    mode:           str
    brightness:     int
    speed:          int
    primaryColor:   str
    secondaryColor: str
    grid:           list
    description:    str


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.post("/ai/predict", response_model=PredictOut)
async def predict_emotion(
    body: PredictIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Predict emotion from band powers using the best available model."""
    bands = body.model_dump()

    # Fetch user baseline for normalisation
    baseline = _get_baseline(db, current_user.id)

    result = ai_svc.predict(bands, user_id=current_user.id, baseline=baseline)

    model_used = _detect_model_source(db, current_user.id)

    return PredictOut(
        emotion=result.emotion.value,
        confidence=round(result.confidence, 3),
        scores=result.emotion_scores or {},
        model_used=model_used,
    )


@router.post("/ai/label", response_model=LabelOut)
async def submit_label(
    body: LabelIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Submit a user-corrected emotion label for training data."""
    if body.label not in _VALID_EMOTIONS:
        raise HTTPException(422, f"Invalid label '{body.label}'. Must be one of {_VALID_EMOTIONS}")

    row = EmotionLabel(
        user_id    = current_user.id,
        session_id = body.session_id,
        label      = body.label,
        source     = "user",
        alpha      = body.alpha,
        beta       = body.beta,
        theta      = body.theta,
        gamma      = body.gamma,
        delta      = body.delta,
        timestamp  = datetime.utcnow(),
        created_at = datetime.utcnow(),
    )
    db.add(row)
    db.commit()
    db.refresh(row)

    n_labels = train_svc.count_labeled_samples(db, user_id=current_user.id)
    auto_train = False

    # Auto-train once we hit the threshold (and at every threshold multiple after)
    if n_labels >= train_svc.AUTO_TRAIN_THRESHOLD and n_labels % train_svc.AUTO_TRAIN_THRESHOLD == 0:
        try:
            train_svc.train(db, user_id=current_user.id)
            auto_train = True
            logger.info("Auto-trained user model after %s labels user=%s", n_labels, current_user.id)
        except ValueError:
            pass

    return LabelOut(
        id=row.id,
        label=row.label,
        n_labels=n_labels,
        auto_train=auto_train,
    )


@router.post("/ai/train", response_model=TrainOut)
async def trigger_training(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Manually trigger model training for the current user."""
    try:
        result = train_svc.train(db, user_id=current_user.id)
    except ValueError as exc:
        raise HTTPException(422, str(exc))

    return TrainOut(**{k: result[k] for k in TrainOut.model_fields})


@router.post("/ai/calibrate", response_model=CalibrateOut)
async def submit_calibration(
    body: CalibrateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Store per-user EEG baseline from the calibration flow."""
    # Use the neutral step for the primary baseline means
    neutral = next((s for s in body.steps if s.step == "neutral"), body.steps[0])

    calibration_data = {
        s.step: {
            "alpha": s.alpha, "beta": s.beta,
            "theta": s.theta, "gamma": s.gamma, "delta": s.delta,
            "duration_seconds": s.duration_seconds,
        }
        for s in body.steps
    }

    existing = db.query(UserBaseline).filter(UserBaseline.user_id == current_user.id).first()
    if existing:
        existing.alpha_mean        = neutral.alpha
        existing.beta_mean         = neutral.beta
        existing.theta_mean        = neutral.theta
        existing.gamma_mean        = neutral.gamma
        existing.delta_mean        = neutral.delta
        existing.calibration_data  = calibration_data
        existing.updated_at        = datetime.utcnow()
    else:
        db.add(UserBaseline(
            user_id           = current_user.id,
            alpha_mean        = neutral.alpha,
            beta_mean         = neutral.beta,
            theta_mean        = neutral.theta,
            gamma_mean        = neutral.gamma,
            delta_mean        = neutral.delta,
            calibration_data  = calibration_data,
        ))

    # Auto-add system labels from calibration steps for training data
    emotion_map = {"neutral": "calm", "focus": "focused", "relax": "relaxed"}
    for step in body.steps:
        mapped = emotion_map.get(step.step)
        if mapped:
            db.add(EmotionLabel(
                user_id    = current_user.id,
                label      = mapped,
                source     = "system",
                alpha      = step.alpha,
                beta       = step.beta,
                theta      = step.theta,
                gamma      = step.gamma,
                delta      = step.delta,
                timestamp  = datetime.utcnow(),
                created_at = datetime.utcnow(),
            ))

    db.commit()

    return CalibrateOut(
        alpha_mean = neutral.alpha,
        beta_mean  = neutral.beta,
        theta_mean = neutral.theta,
        message    = "Calibration saved successfully",
    )


@router.post("/ai/generate-led-pattern", response_model=LedPatternOut)
async def generate_led_pattern(
    body: LedPatternIn,
    current_user: User = Depends(get_current_user),
):
    """Generate an 8×8 LED pattern from a text prompt using Claude AI."""
    pattern = claude_led_service.generate_pattern(
        user_prompt=body.prompt,
        brightness=body.brightness,
        speed=body.speed,
    )
    return LedPatternOut(**pattern)


@router.get("/ai/status", response_model=AiStatusOut)
async def get_ai_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return AI model status for the current user."""
    user_model = (
        db.query(ModelMetadata)
        .filter(ModelMetadata.user_id == current_user.id)
        .order_by(ModelMetadata.trained_at.desc())
        .first()
    )
    global_model = (
        db.query(ModelMetadata)
        .filter(ModelMetadata.user_id.is_(None))
        .order_by(ModelMetadata.trained_at.desc())
        .first()
    )
    n_labels = train_svc.count_labeled_samples(db, user_id=current_user.id)
    labels_until_train = max(0, train_svc.AUTO_TRAIN_THRESHOLD - n_labels)

    return AiStatusOut(
        has_user_model         = user_model is not None,
        has_global_model       = global_model is not None,
        user_model_accuracy    = user_model.accuracy if user_model else None,
        global_model_accuracy  = global_model.accuracy if global_model else None,
        n_user_labels          = n_labels,
        labels_until_train     = labels_until_train,
    )


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_baseline(db, user_id: str) -> Optional[Dict[str, float]]:
    row = db.query(UserBaseline).filter(UserBaseline.user_id == user_id).first()
    if row is None:
        return None
    return {
        "alpha_mean": row.alpha_mean or 0.0,
        "beta_mean":  row.beta_mean  or 0.0,
        "theta_mean": row.theta_mean or 0.0,
        "gamma_mean": row.gamma_mean or 0.0,
        "delta_mean": row.delta_mean or 0.0,
    }


def _detect_model_source(db, user_id: str) -> str:
    from pathlib import Path
    user_meta = (
        db.query(ModelMetadata)
        .filter(ModelMetadata.user_id == user_id)
        .order_by(ModelMetadata.trained_at.desc())
        .first()
    )
    if user_meta:
        p = Path(__file__).parent.parent / "ai_models" / user_meta.model_path
        if p.exists():
            return "ai_user"

    global_meta = (
        db.query(ModelMetadata)
        .filter(ModelMetadata.user_id.is_(None))
        .order_by(ModelMetadata.trained_at.desc())
        .first()
    )
    if global_meta:
        p = Path(__file__).parent.parent / "ai_models" / global_meta.model_path
        if p.exists():
            return "ai_global"

    return "rule_based"
