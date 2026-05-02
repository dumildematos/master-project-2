"""
db_models.py
------------
SQLAlchemy ORM models for Sentio.

Tables
------
users             — registered accounts (email/password or Google OAuth)
session_logs      — EEG session history linked to a user (with state-time breakdown)
brainwave_samples — per-sample EEG + emotion records during a session
emotion_labels    — user-corrected emotion labels for AI training
user_baselines    — per-user EEG baseline from calibration
model_metadata    — trained AI model registry (global and per-user)
"""
import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean, Column, DateTime, Float, ForeignKey,
    Integer, String, Text, JSON,
)
from sqlalchemy.orm import relationship

from database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


class User(Base):
    __tablename__ = "users"

    id           = Column(String(36), primary_key=True, default=_uuid)
    email        = Column(String(254), unique=True, index=True, nullable=False)
    name         = Column(String(120), nullable=True)
    avatar_url   = Column(Text, nullable=True)

    provider     = Column(String(20), nullable=False, default="email")
    provider_id  = Column(String(128), nullable=True, index=True)

    hashed_password = Column(String(128), nullable=True)

    is_active    = Column(Boolean, nullable=False, default=True)
    created_at   = Column(DateTime, nullable=False, default=datetime.utcnow)
    last_login   = Column(DateTime, nullable=True)

    session_logs = relationship(
        "SessionLog", back_populates="user",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<User id={self.id} email={self.email} provider={self.provider}>"


class SessionLog(Base):
    """One EEG monitoring session per row."""
    __tablename__ = "session_logs"

    id               = Column(String(36), primary_key=True, default=_uuid)
    user_id          = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)

    session_type     = Column(String(40), nullable=False, default="monitoring")
    session_title    = Column(String(80), nullable=True)   # "Meditation", "Focus Work", …

    start_time       = Column(DateTime, nullable=False, default=datetime.utcnow)
    end_time         = Column(DateTime, nullable=True)
    duration_seconds = Column(Integer,  nullable=True)

    # EEG summary
    dominant_emotion      = Column(String(20), nullable=True)
    avg_confidence        = Column(Float, nullable=True)
    avg_alpha             = Column(Float, nullable=True)
    avg_beta              = Column(Float, nullable=True)
    avg_theta             = Column(Float, nullable=True)
    avg_gamma             = Column(Float, nullable=True)

    # Per-state focus time breakdown (seconds)
    focus_time_seconds    = Column(Integer, nullable=True, default=0)
    calm_time_seconds     = Column(Integer, nullable=True, default=0)
    relaxed_time_seconds  = Column(Integer, nullable=True, default=0)
    stressed_time_seconds = Column(Integer, nullable=True, default=0)
    excited_time_seconds  = Column(Integer, nullable=True, default=0)

    # Lifecycle status: active | completed | stopped | deleted
    status     = Column(String(20), nullable=False, default="active")
    deleted_at = Column(DateTime, nullable=True)

    notes      = Column(Text, nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    user    = relationship("User", back_populates="session_logs")
    samples = relationship(
        "BrainwaveSample", back_populates="session",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return (
            f"<SessionLog id={self.id} user={self.user_id} "
            f"emotion={self.dominant_emotion} dur={self.duration_seconds}s>"
        )


class BrainwaveSample(Base):
    """One processed EEG snapshot during a session."""
    __tablename__ = "brainwave_samples"

    id             = Column(Integer, primary_key=True, autoincrement=True)
    session_id     = Column(String(36), ForeignKey("session_logs.id"), nullable=False, index=True)

    timestamp      = Column(DateTime, nullable=False, default=datetime.utcnow)

    # Normalised band powers (0–1)
    delta          = Column(Float, nullable=True)
    theta          = Column(Float, nullable=True)
    alpha          = Column(Float, nullable=True)
    beta           = Column(Float, nullable=True)
    gamma          = Column(Float, nullable=True)

    # Derived scores (0–1)
    attention_score   = Column(Float, nullable=True)
    relaxation_score  = Column(Float, nullable=True)
    stress_score      = Column(Float, nullable=True)

    # Classifier output
    detected_state = Column(String(20), nullable=True)
    confidence     = Column(Float, nullable=True)

    session = relationship("SessionLog", back_populates="samples")

    def __repr__(self) -> str:
        return (
            f"<BrainwaveSample id={self.id} session={self.session_id} "
            f"state={self.detected_state} t={self.timestamp}>"
        )


class EmotionLabel(Base):
    """User-submitted or system-generated emotion label for AI training."""
    __tablename__ = "emotion_labels"

    id         = Column(Integer, primary_key=True, autoincrement=True)
    session_id = Column(String(36), ForeignKey("session_logs.id"), nullable=True, index=True)
    user_id    = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    timestamp  = Column(DateTime, nullable=False, default=datetime.utcnow)

    # Band powers at the moment of labelling (snapshot)
    alpha = Column(Float, nullable=True)
    beta  = Column(Float, nullable=True)
    theta = Column(Float, nullable=True)
    gamma = Column(Float, nullable=True)
    delta = Column(Float, nullable=True)

    label      = Column(String(20), nullable=False)  # calm|focused|relaxed|stressed|excited
    source     = Column(String(10), nullable=False, default="user")  # user | system
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    user    = relationship("User")
    session = relationship("SessionLog")

    def __repr__(self) -> str:
        return f"<EmotionLabel id={self.id} user={self.user_id} label={self.label} src={self.source}>"


class UserBaseline(Base):
    """Per-user EEG baseline collected during the calibration session."""
    __tablename__ = "user_baselines"

    id                   = Column(Integer, primary_key=True, autoincrement=True)
    user_id              = Column(String(36), ForeignKey("users.id"), nullable=False, unique=True, index=True)

    # Band-power means from neutral baseline step
    alpha_mean           = Column(Float, nullable=True)
    beta_mean            = Column(Float, nullable=True)
    theta_mean           = Column(Float, nullable=True)
    gamma_mean           = Column(Float, nullable=True)
    delta_mean           = Column(Float, nullable=True)

    # Full per-step data (neutral / focus / relax) stored as JSON
    calibration_data     = Column(JSON, nullable=True)

    created_at           = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at           = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User")

    def __repr__(self) -> str:
        return f"<UserBaseline id={self.id} user={self.user_id}>"


class ModelMetadata(Base):
    """Registry of trained AI emotion models (global and per-user)."""
    __tablename__ = "model_metadata"

    id         = Column(Integer, primary_key=True, autoincrement=True)
    # Null user_id = global shared model; non-null = personalized model
    user_id    = Column(String(36), ForeignKey("users.id"), nullable=True, index=True)

    model_path = Column(String(256), nullable=False)
    model_type = Column(String(40),  nullable=False)  # random_forest | logistic_regression
    accuracy   = Column(Float, nullable=True)
    n_samples  = Column(Integer, nullable=True)
    trained_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    user = relationship("User")

    def __repr__(self) -> str:
        return f"<ModelMetadata id={self.id} user={self.user_id} type={self.model_type} acc={self.accuracy}>"
