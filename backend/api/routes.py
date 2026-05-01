from fastapi import APIRouter, HTTPException
from brainflow.exit_codes import BrainFlowError, BrainFlowExitCodes
from pydantic import BaseModel, Field
from typing import Optional
from config import settings
from eeg.muse_connection import MuseConnection, MuseConnectionError
from services.session_manager import SessionState, session_manager
from eeg.calibration import CalibrationManager
from patterns.pattern_mapper import PatternMapper
from services.stream_service import start_streaming
from models.schemas import (
    SessionConfig,
    SessionStartResponse,
    SessionStatus,
    CalibrationStatus,
    DeviceSource,
    EmotionType,
    PatternParameters,
    PatternType
)

router = APIRouter()


# Initialize calibration and pattern modules
calibration_manager = CalibrationManager()
pattern_mapper = PatternMapper()


def _build_muse_connection(session_config: dict) -> MuseConnection:
    return MuseConnection(
        device_source=session_config.get("device_source") or settings.muse_device_source,
        board_id=int(session_config.get("board_id") or settings.muse_board_id),
        mac_address=session_config.get("mac_address") or settings.muse_mac_address,
        serial_number=session_config.get("serial_number") or settings.muse_serial_number,
        serial_port=session_config.get("serial_port"),
        stream_name=session_config.get("stream_name") or settings.bluemuse_stream_name,
        ppg_stream_name=settings.bluemuse_ppg_stream_name,
        ppg_lsl_stream_type=settings.bluemuse_ppg_lsl_stream_type,
        timeout=int(session_config.get("timeout") or settings.brainflow_connection_timeout),
        stream_buffer_size=settings.brainflow_stream_buffer_size,
        lsl_stream_type=settings.bluemuse_lsl_stream_type,
        lsl_resolve_timeout=settings.bluemuse_lsl_resolve_timeout,
    )


def _brainflow_http_status(error: BrainFlowError) -> int:
    recoverable_codes = {
        BrainFlowExitCodes.BOARD_NOT_READY_ERROR.value,
        BrainFlowExitCodes.INVALID_ARGUMENTS_ERROR.value,
        BrainFlowExitCodes.SYNC_TIMEOUT_ERROR.value,
        BrainFlowExitCodes.PORT_ALREADY_OPEN_ERROR.value,
        BrainFlowExitCodes.UNABLE_TO_OPEN_PORT_ERROR.value,
        BrainFlowExitCodes.SER_PORT_ERROR.value,
    }
    return 400 if error.exit_code in recoverable_codes else 500


# Muse device connection will be created per session


# -----------------------------
# SESSION ENDPOINTS
# -----------------------------


@router.get("/session/devices")
def list_muse_devices():
    """
    Scan for nearby Muse headsets via muselsl BLE advertisement scan.

    Requires muselsl to be installed (already in requirements.txt).
    Takes up to muselsl_scan_timeout seconds (default 5 s).
    Returns a list of dicts with 'name' and 'address' keys.
    """
    from eeg.muse_connection import MuseConnection
    try:
        scan_timeout = settings.muselsl_scan_timeout
    except AttributeError:
        scan_timeout = 5.0
    devices = MuseConnection.discover_muses(timeout=scan_timeout)
    return {"devices": devices, "count": len(devices)}


@router.post(
    "/session/start",
    response_model=SessionStartResponse,
    responses={400: {"description": "Device connection problem"}, 500: {"description": "Unexpected startup failure"}},
)
def start_session(config: SessionConfig):
    """
    Start a new EEG session.

    device_source options
    ─────────────────────
    "mobile"   — Phone acts as BLE bridge; server skips its own BLE.
    "muselsl"  — Pure-Python BLE via muselsl (no external app required).
                 The server discovers the headset, starts an LSL stream
                 thread, and reads EEG via PyLSL.
    "bluemuse" — Read from an LSL stream created by the BlueMuse Windows app.
    "brainflow"— BrainFlow native BLE (headset must be paired in OS settings).
    "auto"     — Try BlueMuse → BrainFlow in order.
    """
    session_config = config.model_dump(mode="json")

    if config.device_source == DeviceSource.mobile:
        # Mobile phone is the BLE bridge — no server-side BLE connection needed.
        session_id = session_manager.start_session(session_config)
        session_manager.set_state(SessionState.RUNNING)
        return {"session_id": session_id, "status": "started"}

    # ── Server-side BLE (muselsl / BrainFlow / BlueMuse / auto) ───────────
    try:
        muse_connection = _build_muse_connection(session_config)
        muse_connection.connect()
    except MuseConnectionError as e:
        raise HTTPException(status_code=e.status_code, detail=f"Device connection failed: {str(e)}")
    except BrainFlowError as e:
        raise HTTPException(status_code=_brainflow_http_status(e), detail=f"Device connection failed: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Device connection failed: {str(e)}")

    session_id = session_manager.start_session(session_config)
    session_manager.muse_connection = muse_connection
    session_manager.set_state(SessionState.CONNECTING)
    start_streaming()
    return {"session_id": session_id, "status": "started"}


@router.post("/session/stop")
def stop_session():
    """
    Stop the active session.
    """
    session_manager.stop_session()
    return {"status": "stopped"}


@router.get("/session/status", response_model=SessionStatus)
def get_session_status():
    """
    Return current session info.
    """
    info = session_manager.get_session_info()
    return SessionStatus(
        session_id=info["session_id"],
        state=info["state"],
        start_time=info["start_time"],
        emotion_history_length=info["emotion_history_length"]
    )


class SessionSensitivityUpdate(BaseModel):
    sensitivity: float = Field(..., ge=0.0, le=1.0)


class SessionEmotionSmoothingUpdate(BaseModel):
    smoothing: float = Field(..., ge=0.0, le=1.0)


@router.patch("/session/sensitivity")
def update_session_sensitivity(payload: SessionSensitivityUpdate):
    """
    Update signal sensitivity during an active EEG session.
    """
    if session_manager.current_session_id is None:
        raise HTTPException(status_code=400, detail="No active session")

    updated = session_manager.update_session_config({"signal_sensitivity": float(payload.sensitivity)})
    return {
        "status": "updated",
        "session_id": session_manager.current_session_id,
        "signal_sensitivity": updated.get("signal_sensitivity"),
    }


@router.patch("/session/emotion-smoothing")
def update_session_emotion_smoothing(payload: SessionEmotionSmoothingUpdate):
    """
    Update emotion smoothing during an active EEG session.
    """
    if session_manager.current_session_id is None:
        raise HTTPException(status_code=400, detail="No active session")

    updated = session_manager.update_session_config({"emotion_smoothing": float(payload.smoothing)})
    return {
        "status": "updated",
        "session_id": session_manager.current_session_id,
        "emotion_smoothing": updated.get("emotion_smoothing"),
    }


# -----------------------------
# CALIBRATION ENDPOINT
# -----------------------------

@router.get(
    "/calibration/run",
    response_model=CalibrationStatus,
    responses={400: {"description": "No active session"}, 500: {"description": "Calibration failure"}},
)
def run_calibration():
    """
    Run EEG calibration (baseline + signal quality).
    """
    if not session_manager.is_active():
        raise HTTPException(status_code=400, detail="No active session")

    # Here we would pass the Muse connection to calibration
    # Retrieve the active MuseConnection from session_manager
    muse_connection = getattr(session_manager, 'muse_connection', None)
    if muse_connection is None:
        raise HTTPException(status_code=500, detail="No BrainFlow connection instance found for calibration")
    was_streaming = session_manager.is_streaming()

    if was_streaming:
        session_manager.set_state(SessionState.CALIBRATING)
        session_manager.request_stream_stop()
        session_manager.wait_for_stream_stop(timeout=2.0)

    try:
        calibration_result = calibration_manager.run_calibration(
            muse_connection=muse_connection
        )

        if calibration_result is None:
            raise HTTPException(status_code=500, detail="Calibration failed")

        return CalibrationStatus(
            progress=1.0,  # Simplified for demo
            signal_quality=calibration_result["signal_quality"],
            noise_level=0.0,  # Optional: compute from EEG data
            status_message="Calibration complete"
        )
    finally:
        if was_streaming and session_manager.current_session_id is not None:
            session_manager.set_state(SessionState.CONNECTING)
            start_streaming()


# -----------------------------
# MANUAL OVERRIDE ENDPOINT
# -----------------------------

class ManualOverridePayload(BaseModel):
    alpha:      float = Field(default=0.55, ge=0.0, le=1.0)
    beta:       float = Field(default=0.18, ge=0.0, le=1.0)
    theta:      float = Field(default=0.15, ge=0.0, le=1.0)
    gamma:      float = Field(default=0.08, ge=0.0, le=1.0)
    delta:      float = Field(default=0.04, ge=0.0, le=1.0)
    confidence: float = Field(default=0.82, ge=0.0, le=1.0)
    emotion:    str   = Field(default="calm")


@router.post("/manual/override", status_code=200)
def send_manual_override(payload: ManualOverridePayload):
    """
    Inject manually overridden EEG band values and emotion into the live
    WebSocket stream. Used by the frontend Manual Mode panel.
    """
    import time
    from services.session_manager import session_manager as sm
    message = {
        "timestamp": float(time.time()),
        "alpha":         payload.alpha,
        "beta":          payload.beta,
        "theta":         payload.theta,
        "gamma":         payload.gamma,
        "delta":         payload.delta,
        "confidence":    payload.confidence,
        "emotion":       payload.emotion,
        "signal_quality": payload.confidence * 100,
        "active":        1,
        "manual":        True,
    }
    sm.set_latest_stream_message(message)
    return {"status": "ok", "emotion": payload.emotion}


# -----------------------------
# MOBILE BLE BANDS ENDPOINT
# -----------------------------

class MobileBandsPayload(BaseModel):
    """
    EEG band powers computed on the mobile phone from raw Muse 2 BLE data.
    Values are already normalized (each band 0–1, they should roughly sum to 1).
    """
    alpha:          float = Field(..., ge=0.0, le=1.0)
    beta:           float = Field(..., ge=0.0, le=1.0)
    theta:          float = Field(..., ge=0.0, le=1.0)
    gamma:          float = Field(..., ge=0.0, le=1.0)
    delta:          float = Field(..., ge=0.0, le=1.0)
    signal_quality: float = Field(default=75.0, ge=0.0, le=100.0)


@router.post("/eeg/mobile-bands", status_code=200)
def receive_mobile_bands(payload: MobileBandsPayload):
    """
    Receive pre-computed EEG band powers from the mobile Muse 2 BLE bridge.
    Runs the full server-side pipeline (emotion classification, AI guidance,
    AI pattern) and broadcasts the result via the existing WebSocket stream.
    """
    if not session_manager.is_active():
        raise HTTPException(status_code=400, detail="No active session — call /session/start first")

    features = {
        "alpha":          payload.alpha,
        "beta":           payload.beta,
        "theta":          payload.theta,
        "gamma":          payload.gamma,
        "delta":          payload.delta,
        "signal_quality": payload.signal_quality,
    }
    from services.stream_service import process_bands_from_mobile
    process_bands_from_mobile(features)
    return {"status": "ok"}


# -----------------------------
# PATTERN ENDPOINTS
# -----------------------------

_VALID_ARDUINO_PATTERNS = frozenset({
    "fluid", "breathing", "geometric", "fireworks", "stress", "pulse", "stars",
})


class PatternSelectPayload(BaseModel):
    pattern_type: Optional[str] = Field(
        default=None,
        description=(
            "One of: fluid, breathing, geometric, fireworks, stress, pulse, stars. "
            "Omit or pass null to restore automatic AI/emotion-based selection."
        ),
    )


@router.post("/pattern/select")
def select_pattern(payload: PatternSelectPayload):
    """
    Override the Arduino LED pattern type for the active session.
    The emotion-matched colour palette is preserved — only the animation changes.
    Pass pattern_type=null to restore automatic AI selection.
    """
    pt = payload.pattern_type or None
    if pt and pt not in _VALID_ARDUINO_PATTERNS:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown pattern '{pt}'. Valid: {sorted(_VALID_ARDUINO_PATTERNS)}",
        )
    session_manager.set_user_pattern_override(pt)
    return {"status": "ok", "pattern_type": pt, "auto": pt is None}


@router.get(
    "/pattern/generate",
    response_model=PatternParameters,
    responses={400: {"description": "Invalid emotion supplied"}},
)
def generate_pattern(emotion: str, pattern_type: PatternType):
    """
    Generate pattern parameters based on emotion and EEG features.
    """
    # Use the last emotion from session history if available
    if session_manager.emotion_history:
        latest_emotion = session_manager.emotion_history[-1].get("emotion", emotion)
    else:
        latest_emotion = emotion

    try:
        emotion_value = EmotionType(latest_emotion)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=f"Unknown emotion: {latest_emotion}") from exc

    latest_stream_message = session_manager.get_latest_stream_message() or {}
    eeg_features = {
        band: float(latest_stream_message.get(band, 0.0) or 0.0)
        for band in ("alpha", "beta", "gamma", "theta", "delta")
    }


    pattern_params = pattern_mapper.map_pattern(
        emotion=emotion_value,
        eeg_features=eeg_features,
        selected_pattern=pattern_type
    )

    return pattern_params