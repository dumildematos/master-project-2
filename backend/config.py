from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Global configuration for Sentio backend.
    Reads values from environment variables and the backend/.env file.
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # FastAPI / server
    app_name: str = "Sentio EEG Backend"
    host: str = "0.0.0.0"
    port: int = 8000
    debug: bool = True
    cors_allowed_origins: list[str] = Field(
        default_factory=lambda: [
            "http://localhost",
            "http://127.0.0.1",
            "http://10.208.194.6",
        ]
    )
    # Allows: localhost / 127.0.0.1 (any port), LAN IP, and any *.vercel.app deploy
    cors_allowed_origin_regex: str = (
        r"^https?://(localhost|127\.0\.0\.1|10\.208\.193\.106)(:\d+)?$"
        r"|^https://[a-zA-Z0-9\-]+\.vercel\.app$"
    )

    # BrainFlow / Muse 2 configuration
    muse_device_source: str = "auto"
    muse_board_id: int = 38  # BoardIds.MUSE_2_BOARD.value
    muse_sampling_rate: int = 256  # Hz
    muse_window_size: int = 128  # samples per read for lower stream latency
    muse_mac_address: str | None = None
    muse_serial_number: str | None = None
    brainflow_connection_timeout: int = 15
    brainflow_stream_buffer_size: int = 45000
    bluemuse_stream_name: str | None = None
    bluemuse_lsl_stream_type: str = "EEG"
    bluemuse_ppg_stream_name: str | None = None
    bluemuse_ppg_lsl_stream_type: str = "PPG"
    bluemuse_lsl_resolve_timeout: float = 3.0

    # EEG processing
    eeg_update_interval: float = 0.05  # target cadence for publishing fresh EEG frames
    heart_rate_window_seconds: float = 12.0

    # Calibration
    calibration_duration: int = 5  # seconds for baseline
    noise_threshold: float = 0.5  # optional: signal quality threshold

    # Pattern mapping
    default_pattern_type: str = "organic"

    # WebSocket
    ws_endpoint: str = "/ws/brain-stream"

    # Claude AI guidance + AI-generated LED patterns
    # Set ANTHROPIC_API_KEY in backend/.env — falls back gracefully when absent
    anthropic_api_key: str | None = None
    guidance_model: str = "claude-haiku-4-5"
    guidance_cache_ttl: float = 20.0   # seconds before re-fetching guidance for same state
    pattern_cache_ttl: float  = 30.0   # seconds before re-fetching AI pattern for same state


# Single global settings instance
settings = Settings()
