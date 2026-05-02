"""
model_training_service.py
--------------------------
Collects labeled EEG samples, engineers features, trains an sklearn
RandomForest (with LogisticRegression fallback), evaluates, persists the
model file, and registers it in ModelMetadata.

Training is triggered:
  • manually via POST /ai/train
  • automatically after N labeled samples are saved (handled by ai_router)

Minimum labeled samples required before training is attempted.
"""
import logging
import os
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import numpy as np

logger = logging.getLogger("sentio.training")

_MIN_SAMPLES = 20          # minimum labels before we attempt training
_TEST_SPLIT  = 0.20        # 20 % held-out test set
_MODELS_DIR  = Path(__file__).parent.parent / "ai_models"
_LABELS      = ["calm", "focused", "relaxed", "stressed", "excited"]

# Auto-train threshold — trigger after this many new labeled samples
AUTO_TRAIN_THRESHOLD = 50


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def collect_labeled_data(
    db,
    user_id: Optional[str] = None,
) -> Tuple[List[Dict], List[str]]:
    """
    Load EmotionLabel rows + their band-power snapshots from the database.

    Returns (features_list, labels_list).  If user_id is given, only that
    user's labels are returned; otherwise all labels are collected (global).
    """
    from models.db_models import EmotionLabel

    query = db.query(EmotionLabel)
    if user_id:
        query = query.filter(EmotionLabel.user_id == user_id)

    rows = query.all()
    features_list, labels_list = [], []
    for row in rows:
        if row.label not in _LABELS:
            continue
        features_list.append({
            "alpha": row.alpha or 0.0,
            "beta":  row.beta  or 0.0,
            "theta": row.theta or 0.0,
            "gamma": row.gamma or 0.0,
            "delta": row.delta or 0.0,
        })
        labels_list.append(row.label)

    return features_list, labels_list


def train(
    db,
    user_id: Optional[str] = None,
) -> Dict:
    """
    Full training pipeline.

    1. Load labeled data
    2. Extract features
    3. Split train/test
    4. Train RandomForest (fallback: LogisticRegression)
    5. Evaluate accuracy
    6. Save model to disk
    7. Register in ModelMetadata

    Returns a summary dict with accuracy, n_samples, model_type, model_path.
    Raises ValueError if there are insufficient samples.
    """
    from services.brainwave_feature_extractor import BrainwaveFeatureExtractor

    raw_features, labels = collect_labeled_data(db, user_id=user_id)
    n = len(raw_features)

    if n < _MIN_SAMPLES:
        raise ValueError(
            f"Need at least {_MIN_SAMPLES} labeled samples to train "
            f"(have {n} for {'user ' + user_id if user_id else 'global model'})"
        )

    # Feature engineering
    extractor = BrainwaveFeatureExtractor()
    X = np.array([
        BrainwaveFeatureExtractor.to_vector(extractor.extract(f))
        for f in raw_features
    ], dtype=np.float64)
    y = np.array(labels)

    # Train/test split (stratified when possible)
    X_train, X_test, y_train, y_test = _split(X, y)

    # Train
    model, model_type = _fit(X_train, y_train)

    # Evaluate
    accuracy = float(np.mean(model.predict(X_test) == y_test))

    # Persist
    _models_dir().mkdir(parents=True, exist_ok=True)
    filename = _model_filename(user_id)
    path     = _models_dir() / filename
    _save_model(model, path)

    # Register
    _register(db, user_id=user_id, filename=filename, model_type=model_type,
               accuracy=accuracy, n_samples=n)

    # Invalidate in-process cache so next prediction picks up the new file
    from services.ai_emotion_service import invalidate_cache
    invalidate_cache(user_id)

    logger.info(
        "Training complete user=%s type=%s samples=%s acc=%.3f path=%s",
        user_id or "global", model_type, n, accuracy, path,
    )

    return {
        "model_type":  model_type,
        "accuracy":    round(accuracy, 4),
        "n_samples":   n,
        "model_path":  filename,
        "user_id":     user_id,
        "trained_at":  datetime.utcnow().isoformat(),
    }


def count_labeled_samples(db, user_id: Optional[str] = None) -> int:
    from models.db_models import EmotionLabel
    q = db.query(EmotionLabel)
    if user_id:
        q = q.filter(EmotionLabel.user_id == user_id)
    return q.count()


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _split(X, y):
    from sklearn.model_selection import train_test_split
    try:
        return train_test_split(X, y, test_size=_TEST_SPLIT, random_state=42, stratify=y)
    except ValueError:
        return train_test_split(X, y, test_size=_TEST_SPLIT, random_state=42)


def _fit(X_train, y_train) -> Tuple[object, str]:
    try:
        from sklearn.ensemble import RandomForestClassifier
        model = RandomForestClassifier(
            n_estimators=150,
            max_depth=12,
            min_samples_leaf=2,
            random_state=42,
            n_jobs=-1,
        )
        model.fit(X_train, y_train)
        return model, "random_forest"
    except Exception as exc:
        logger.warning("RandomForest failed (%s), trying LogisticRegression", exc)
        from sklearn.linear_model import LogisticRegression
        from sklearn.preprocessing import StandardScaler
        from sklearn.pipeline import Pipeline
        model = Pipeline([
            ("scaler", StandardScaler()),
            ("clf",    LogisticRegression(max_iter=1000, random_state=42)),
        ])
        model.fit(X_train, y_train)
        return model, "logistic_regression"


def _save_model(model, path: Path) -> None:
    import joblib
    joblib.dump(model, path)


def _register(
    db,
    user_id: Optional[str],
    filename: str,
    model_type: str,
    accuracy: float,
    n_samples: int,
) -> None:
    from models.db_models import ModelMetadata

    row = ModelMetadata(
        user_id    = user_id,
        model_path = filename,
        model_type = model_type,
        accuracy   = accuracy,
        n_samples  = n_samples,
        trained_at = datetime.utcnow(),
    )
    db.add(row)
    db.commit()


def _model_filename(user_id: Optional[str]) -> str:
    tag = f"user_{user_id}" if user_id else "global"
    return f"{tag}_model.pkl"


def _models_dir() -> Path:
    return _MODELS_DIR
