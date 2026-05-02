import time
import logging
from collections import deque

from config import settings
from eeg.muse_connection import MuseConnection
from eeg.signal_processing import SignalProcessor
from emotion.emotion_model import EmotionModel
from heart_rate import HeartRateProcessor
from models.schemas import EmotionResult, EmotionType, PatternType
from patterns.pattern_mapper import PatternMapper
from services.session_manager import SessionState, session_manager
from services.guidance_service import get_guidance
from services.pattern_service import get_ai_pattern

logger = logging.getLogger("sentio.stream")

IDLE_BACKOFF_SECONDS = 0.02
EMOTION_HISTORY_MAXLEN = 7
_SAMPLE_SAVE_EVERY_N_FRAMES = 10  # ~2 Hz at 50 ms update interval
EMOTION_RECENCY_MIN_STEP = 0.12
EMOTION_RECENCY_MAX_STEP = 0.75
EMOTION_OVERRIDE_CONFIDENCE_BASE = 0.72
EMOTION_OVERRIDE_CONFIDENCE_RANGE = 0.20

processor = SignalProcessor(settings.muse_sampling_rate)
emotion_model = EmotionModel()
pattern_mapper = PatternMapper()
emotion_window = deque(maxlen=EMOTION_HISTORY_MAXLEN)
heart_rate_processor = HeartRateProcessor(
    settings.muse_sampling_rate,
    settings.heart_rate_window_seconds,
)


def _apply_user_pattern_override(ai_pattern: dict | None) -> dict | None:
    """
    If the user has selected a specific pattern type, force it into the
    ai_pattern dict while keeping the AI-generated colours and parameters.
    Returns None when no AI pattern is available yet.
    """
    override = session_manager.get_user_pattern_override()
    if not override or ai_pattern is None:
        return ai_pattern
    return {**ai_pattern, "pattern_type": override}


def _get_emotion_smoothing() -> float:
    configured = session_manager.session_config.get("emotion_smoothing", 0.5)
    try:
        return min(max(float(configured), 0.0), 1.0)
    except (TypeError, ValueError):
        return 0.5


def _get_selected_pattern() -> PatternType:
    configured_pattern = session_manager.session_config.get(
        "pattern_type",
        settings.default_pattern_type,
    )
    if isinstance(configured_pattern, PatternType):
        return configured_pattern

    try:
        return PatternType(configured_pattern)
    except ValueError:
        return PatternType(settings.default_pattern_type)


def _get_or_create_muse_connection() -> MuseConnection:
    muse_connection = session_manager.muse_connection
    if muse_connection is None:
        muse_connection = MuseConnection(
            device_source=session_manager.session_config.get("device_source") or settings.muse_device_source,
            board_id=int(session_manager.session_config.get("board_id") or settings.muse_board_id),
            mac_address=session_manager.session_config.get("mac_address") or settings.muse_mac_address,
            serial_number=session_manager.session_config.get("serial_number") or settings.muse_serial_number,
            serial_port=session_manager.session_config.get("serial_port"),
            stream_name=session_manager.session_config.get("stream_name") or settings.bluemuse_stream_name,
            ppg_stream_name=settings.bluemuse_ppg_stream_name,
            ppg_lsl_stream_type=settings.bluemuse_ppg_lsl_stream_type,
            timeout=int(
                session_manager.session_config.get("timeout") or settings.brainflow_connection_timeout
            ),
            stream_buffer_size=settings.brainflow_stream_buffer_size,
            lsl_stream_type=settings.bluemuse_lsl_stream_type,
            lsl_resolve_timeout=settings.bluemuse_lsl_resolve_timeout,
        )
        session_manager.muse_connection = muse_connection
    return muse_connection


def _build_stream_config(muse_connection: MuseConnection, pattern_type: PatternType) -> dict:
    return {
        "session_id": session_manager.current_session_id,
        "state": session_manager.session_state,
        "device_source": muse_connection.active_source or session_manager.session_config.get("device_source") or settings.muse_device_source,
        "board_id": int(muse_connection.board_id),
        "age": session_manager.session_config.get("age"),
        "gender": session_manager.session_config.get("gender"),
        "sampling_rate": int(muse_connection.sampling_rate or settings.muse_sampling_rate),
        "channel_count": int(muse_connection.eeg_channels or 0),
        "window_size": settings.muse_window_size,
        "update_interval": settings.eeg_update_interval,
        "pattern_type": pattern_type.value,
        "signal_sensitivity": session_manager.session_config.get("signal_sensitivity"),
        "emotion_smoothing": session_manager.session_config.get("emotion_smoothing"),
        "noise_control": session_manager.session_config.get("noise_control"),
        "heart_signal_source": muse_connection.heart_signal_source,
    }


def _log_empty_read(muse_connection: MuseConnection, empty_reads: int, last_no_data_log: float) -> float:
    now = time.monotonic()
    if now - last_no_data_log >= 5.0:
        logger.info(
            "Stream waiting for EEG samples session_id=%s empty_reads=%s diagnostics=%s",
            session_manager.current_session_id,
            empty_reads,
            muse_connection.get_runtime_diagnostics(),
        )
        return now

    return last_no_data_log


def _log_feature_failure(eeg_data, feature_failures: int, last_no_features_log: float) -> float:
    now = time.monotonic()
    if now - last_no_features_log >= 5.0:
        shape = getattr(eeg_data, "shape", None)
        logger.info(
            "Stream received EEG data but feature extraction returned no result session_id=%s feature_failures=%s shape=%s sampling_rate=%s",
            session_manager.current_session_id,
            feature_failures,
            shape,
            processor.sampling_rate,
        )
        return now

    return last_no_features_log


def _start_stream_runtime(muse_connection: MuseConnection) -> tuple[PatternType, dict]:
    if not muse_connection.is_connected():
        muse_connection.connect()

    logger.info(
        "Stream loop started session_id=%s source=%s board_id=%s",
        session_manager.current_session_id,
        muse_connection.active_source or session_manager.session_config.get("device_source") or settings.muse_device_source,
        muse_connection.board_id,
    )

    processor.sampling_rate = int(muse_connection.sampling_rate or settings.muse_sampling_rate)
    emotion_window.clear()
    heart_rate_processor.reset(sample_rate=int(muse_connection.sampling_rate or settings.muse_sampling_rate))
    selected_pattern = _get_selected_pattern()
    stream_config = _build_stream_config(muse_connection, selected_pattern)
    session_manager.set_state(SessionState.RUNNING)
    return selected_pattern, stream_config


def _compute_signal_quality(features: dict) -> float:
    """
    Estimate signal quality (0–100) from band-power distribution.

    Clean EEG is dominated by alpha (0.25–0.5 of total).  Very noisy or
    disconnected electrodes produce flat, near-equal band powers where alpha
    is suppressed.  We use the alpha-to-total ratio as a proxy, scaled to
    0–100 so the frontend disconnect detector thresholds (15 / 38) work
    correctly without any client-side rescaling.
    """
    alpha = features.get("alpha", 0.0)
    beta  = features.get("beta",  0.0)
    theta = features.get("theta", 0.0)
    # Alpha + theta together form the "calm resting" bands — good signal
    # quality correlates with these being well above noise floor.
    dominant = alpha + theta + beta
    # Scale to 0-100; typical good-signal dominant ≈ 0.75 → maps to 100
    quality = min(100.0, dominant * 133.0)
    return round(quality, 1)


def _build_stream_message(
    features,
    emotion_result,
    pattern_params,
    selected_pattern: PatternType,
    stream_config: dict,
    heart_metrics: dict | None,
) -> dict:
    stream_config["state"] = session_manager.session_state
    stream_config["signal_sensitivity"] = session_manager.session_config.get("signal_sensitivity")
    stream_config["emotion_smoothing"] = session_manager.session_config.get("emotion_smoothing")
    stream_config["noise_control"] = session_manager.session_config.get("noise_control")
    stream_config["heart_signal_source"] = stream_config.get("heart_signal_source")
    return {
        "timestamp": float(time.time()),
        "alpha": float(features["alpha"]),
        "beta": float(features["beta"]),
        "gamma": float(features["gamma"]),
        "theta": float(features["theta"]),
        "delta": float(features["delta"]),
        "signal_quality": _compute_signal_quality(features),
        "heart_bpm": heart_metrics.get("heart_bpm") if heart_metrics else None,
        "heart_confidence": heart_metrics.get("heart_confidence") if heart_metrics else None,
        "respiration_rpm": heart_metrics.get("respiration_rpm") if heart_metrics else None,
        "respiration_confidence": heart_metrics.get("respiration_confidence") if heart_metrics else None,
        "emotion": emotion_result.emotion.value,
        "confidence": float(emotion_result.confidence),
        "detected_emotion": (
            emotion_result.detected_emotion.value
            if emotion_result.detected_emotion is not None
            else emotion_result.emotion.value
        ),
        "detected_confidence": (
            float(emotion_result.detected_confidence)
            if emotion_result.detected_confidence is not None
            else float(emotion_result.confidence)
        ),
        "mindfulness": (
            float(emotion_result.mindfulness)
            if emotion_result.mindfulness is not None
            else None
        ),
        "restfulness": (
            float(emotion_result.restfulness)
            if emotion_result.restfulness is not None
            else None
        ),
        "pattern_seed": int(pattern_params.pattern_seed),
        "pattern_complexity": float(pattern_params.complexity),
        "color_palette": [str(color) for color in pattern_params.color_palette],
        "config": stream_config,
        "age": stream_config.get("age"),
        "gender": stream_config.get("gender"),
        "pattern_type": session_manager.get_user_pattern_override() or selected_pattern.value,
        "active": 1,
        "ai_guidance": get_guidance(
            emotion=emotion_result.emotion.value,
            confidence=float(emotion_result.confidence),
            alpha=float(features["alpha"]),
            beta=float(features["beta"]),
            theta=float(features["theta"]),
            gamma=float(features["gamma"]),
            delta=float(features["delta"]),
            mindfulness=(
                float(emotion_result.mindfulness)
                if emotion_result.mindfulness is not None else None
            ),
            restfulness=(
                float(emotion_result.restfulness)
                if emotion_result.restfulness is not None else None
            ),
        ),
        # AI-generated LED pattern definition (None until first Claude response,
        # then cached per emotion/confidence bucket).  When present the Arduino
        # uses these values instead of its own static palette/parameter logic.
        "ai_pattern": _apply_user_pattern_override(get_ai_pattern(
            emotion=emotion_result.emotion.value,
            confidence=float(emotion_result.confidence),
            alpha=float(features["alpha"]),
            beta=float(features["beta"]),
            theta=float(features["theta"]),
            gamma=float(features["gamma"]),
            delta=float(features["delta"]),
        )),
        # Explicit user selection (None = AI/auto).  Forwarded to clients so
        # the frontend and Arduino know which pattern was user-requested.
        "user_pattern_override": session_manager.get_user_pattern_override(),
    }


def _compute_heart_metrics(muse_connection: MuseConnection, stream_config: dict) -> dict | None:
    target_window = max(
        int((muse_connection.sampling_rate or settings.muse_sampling_rate) * settings.heart_rate_window_seconds),
        settings.muse_window_size,
    )
    signal, sample_rate, source = muse_connection.get_heart_signal(window_size=target_window)
    stream_config["heart_signal_source"] = source

    if signal is None or sample_rate is None or sample_rate <= 0:
        return None

    return heart_rate_processor.update(signal, sample_rate=sample_rate)


def _stabilize_emotion(emotion_result: EmotionResult) -> EmotionResult:
    emotion_window.append((emotion_result.emotion, float(emotion_result.confidence)))

    smoothing = _get_emotion_smoothing()
    active_window_size = max(1, int(round(1 + (smoothing * (EMOTION_HISTORY_MAXLEN - 1)))))
    recent_emotions = list(emotion_window)[-active_window_size:]
    recency_step = EMOTION_RECENCY_MAX_STEP - (
        smoothing * (EMOTION_RECENCY_MAX_STEP - EMOTION_RECENCY_MIN_STEP)
    )

    weighted_scores: dict[EmotionType, float] = {}
    for index, (emotion, confidence) in enumerate(reversed(recent_emotions)):
        recency_weight = 1.0 + (index * recency_step)
        weighted_scores[emotion] = weighted_scores.get(emotion, 0.0) + (confidence / recency_weight)

    stable_emotion = max(weighted_scores, key=weighted_scores.get, default=emotion_result.emotion)
    stable_confidence = weighted_scores.get(stable_emotion, float(emotion_result.confidence)) / max(len(recent_emotions), 1)

    override_threshold = EMOTION_OVERRIDE_CONFIDENCE_BASE + (smoothing * EMOTION_OVERRIDE_CONFIDENCE_RANGE)
    if stable_emotion != emotion_result.emotion and float(emotion_result.confidence) >= override_threshold:
        stable_emotion = emotion_result.emotion
        stable_confidence = float(emotion_result.confidence)

    if stable_emotion == emotion_result.emotion:
        stable_confidence = max(stable_confidence, float(emotion_result.confidence))

    return emotion_result.model_copy(update={
        "emotion": stable_emotion,
        "confidence": round(float(min(max(stable_confidence, 0.0), 1.0)), 3),
        "detected_emotion": emotion_result.emotion,
        "detected_confidence": round(float(emotion_result.confidence), 3),
    })


def _log_frame_progress(message: dict, frames_emitted: int, last_progress_log: float) -> float:
    now = time.monotonic()
    if frames_emitted == 1 or now - last_progress_log >= 5.0:
        logger.info(
            "Stream produced frame %s session_id=%s emotion=%s confidence=%.3f",
            frames_emitted,
            session_manager.current_session_id,
            message["emotion"],
            message["confidence"],
        )
        return now

    return last_progress_log


def _handle_stream_error(exc: Exception, frames_emitted: int):
    logger.exception(
        "Stream error for session_id=%s after %s frames: %s",
        session_manager.current_session_id,
        frames_emitted,
        exc,
    )
    session_manager.set_state(SessionState.IDLE)
    if session_manager.muse_connection is not None:
        session_manager.muse_connection.disconnect()
        session_manager.muse_connection = None
    session_manager.clear_latest_stream_message()


def _process_stream_iteration(
    muse_connection: MuseConnection,
    selected_pattern: PatternType,
    stream_config: dict,
    last_no_data_log: float,
    last_no_features_log: float,
    last_progress_log: float,
    empty_reads: int,
    feature_failures: int,
    frames_emitted: int,
) -> tuple[float, float, float, int, int, int]:
    eeg_data = muse_connection.get_eeg_data(window_size=settings.muse_window_size)
    if eeg_data is None:
        empty_reads += 1
        last_no_data_log = _log_empty_read(muse_connection, empty_reads, last_no_data_log)
        time.sleep(IDLE_BACKOFF_SECONDS)
        return (
            last_no_data_log,
            last_no_features_log,
            last_progress_log,
            empty_reads,
            feature_failures,
            frames_emitted,
        )

    features = processor.extract_features(eeg_data)
    if features is None:
        feature_failures += 1
        last_no_features_log = _log_feature_failure(eeg_data, feature_failures, last_no_features_log)
        time.sleep(IDLE_BACKOFF_SECONDS)
        return (
            last_no_data_log,
            last_no_features_log,
            last_progress_log,
            empty_reads,
            feature_failures,
            frames_emitted,
        )

    emotion_result = _stabilize_emotion(emotion_model.predict(features))
    session_manager.add_emotion(
        emotion_result.emotion.value,
        confidence=float(emotion_result.confidence),
        detected_emotion=(
            emotion_result.detected_emotion.value
            if emotion_result.detected_emotion is not None
            else emotion_result.emotion.value
        ),
    )
    pattern_params = pattern_mapper.map_pattern(
        emotion=emotion_result.emotion,
        eeg_features=features,
        selected_pattern=selected_pattern,
        signal_sensitivity=float(session_manager.session_config.get("signal_sensitivity", 0.5) or 0.5),
    )
    heart_metrics = _compute_heart_metrics(muse_connection, stream_config)
    message = _build_stream_message(
        features,
        emotion_result,
        pattern_params,
        selected_pattern,
        stream_config,
        heart_metrics,
    )

    session_manager.set_latest_stream_message(message)
    frames_emitted += 1
    last_progress_log = _log_frame_progress(message, frames_emitted, last_progress_log)

    if frames_emitted % _SAMPLE_SAVE_EVERY_N_FRAMES == 0:
        db_session_id = session_manager.get_db_session_id()
        if db_session_id:
            from services import session_service
            session_service.save_sample_from_stream(
                db_session_id=db_session_id,
                features=features,
                emotion=emotion_result.emotion.value,
                confidence=float(emotion_result.confidence),
            )

    time.sleep(settings.eeg_update_interval)
    return (
        last_no_data_log,
        last_no_features_log,
        last_progress_log,
        empty_reads,
        feature_failures,
        frames_emitted,
    )


def _run_stream_loop():
    muse_connection = _get_or_create_muse_connection()
    frames_emitted = 0
    last_progress_log = 0.0
    last_no_data_log = 0.0
    last_no_features_log = 0.0
    empty_reads = 0
    feature_failures = 0

    try:
        selected_pattern, stream_config = _start_stream_runtime(muse_connection)

        while session_manager.is_active() and not session_manager.stream_stop_event.is_set():
            (
                last_no_data_log,
                last_no_features_log,
                last_progress_log,
                empty_reads,
                feature_failures,
                frames_emitted,
            ) = _process_stream_iteration(
                muse_connection,
                selected_pattern,
                stream_config,
                last_no_data_log,
                last_no_features_log,
                last_progress_log,
                empty_reads,
                feature_failures,
                frames_emitted,
            )
    except Exception as exc:
        _handle_stream_error(exc, frames_emitted)
    finally:
        session_manager.mark_stream_stopped()
        logger.info(
            "Stream loop stopped session_id=%s emitted_frames=%s empty_reads=%s feature_failures=%s state=%s",
            session_manager.current_session_id,
            frames_emitted,
            empty_reads,
            feature_failures,
            session_manager.session_state,
        )


def process_bands_from_mobile(features: dict) -> None:
    """
    Process EEG band powers received from the mobile phone (Muse 2 via phone BLE).

    Runs the same pipeline as the normal stream loop — emotion classification,
    stabilisation, pattern mapping, AI guidance, AI pattern — and broadcasts
    the result via the WebSocket stream without touching the BrainFlow /
    BlueMuse connection (there is none for mobile-source sessions).
    """
    selected_pattern = _get_selected_pattern()

    emotion_result = _stabilize_emotion(emotion_model.predict(features))
    session_manager.add_emotion(
        emotion_result.emotion.value,
        confidence=float(emotion_result.confidence),
        detected_emotion=(
            emotion_result.detected_emotion.value
            if emotion_result.detected_emotion is not None
            else emotion_result.emotion.value
        ),
    )

    pattern_params = pattern_mapper.map_pattern(
        emotion=emotion_result.emotion,
        eeg_features=features,
        selected_pattern=selected_pattern,
        signal_sensitivity=float(
            session_manager.session_config.get("signal_sensitivity", 0.5) or 0.5
        ),
    )

    # Minimal stream config — no BLE connection to query for hw info
    stream_config = {
        "session_id":        session_manager.current_session_id,
        "state":             session_manager.session_state,
        "device_source":     "mobile",
        "board_id":          38,   # Muse 2
        "age":               session_manager.session_config.get("age"),
        "gender":            session_manager.session_config.get("gender"),
        "sampling_rate":     256,
        "channel_count":     4,
        "window_size":       settings.muse_window_size,
        "update_interval":   settings.eeg_update_interval,
        "pattern_type":      selected_pattern.value,
        "signal_sensitivity": session_manager.session_config.get("signal_sensitivity"),
        "emotion_smoothing": session_manager.session_config.get("emotion_smoothing"),
        "noise_control":     session_manager.session_config.get("noise_control"),
        "heart_signal_source": None,
    }

    message = _build_stream_message(
        features, emotion_result, pattern_params, selected_pattern, stream_config, None
    )
    session_manager.set_latest_stream_message(message)

    db_session_id = session_manager.get_db_session_id()
    if db_session_id:
        from services import session_service
        session_service.save_sample_from_stream(
            db_session_id=db_session_id,
            features=features,
            emotion=emotion_result.emotion.value,
            confidence=float(emotion_result.confidence),
        )

    logger.debug(
        "Mobile bands processed session_id=%s emotion=%s confidence=%.3f",
        session_manager.current_session_id,
        message["emotion"],
        message["confidence"],
    )


def start_streaming() -> bool:
    started = session_manager.start_stream_thread(_run_stream_loop)
    logger.info(
        "Stream thread start requested session_id=%s started=%s",
        session_manager.current_session_id,
        started,
    )
    return started