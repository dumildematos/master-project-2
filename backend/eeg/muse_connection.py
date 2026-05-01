import logging
import sys
import threading
import time
from typing import Optional

import numpy as np
from brainflow.board_shim import BoardIds, BoardShim, BrainFlowInputParams
from brainflow.exit_codes import BrainFlowError, BrainFlowExitCodes

try:
    from pylsl import StreamInlet, resolve_byprop
except ImportError:
    StreamInlet = None
    resolve_byprop = None


logger = logging.getLogger("sentio.muse")


class MuseConnectionError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.status_code = status_code


class MuseConnection:
    """
    Unified EEG source for Muse headsets.

    Supported device_source values
    ───────────────────────────────
    "auto"      Try BlueMuse LSL → BrainFlow native BLE in order.
    "brainflow" BrainFlow native BLE (no external app needed, but
                requires the headset paired in Windows Bluetooth settings).
    "bluemuse"  Connect to an LSL stream created by the BlueMuse Windows app.
    "muselsl"   Pure-Python BLE via the muselsl package (pip install muselsl).
                Discovers the headset, starts an LSL outlet in a background
                thread, then reads via PyLSL — no external app required.
    "mobile"    Handled entirely in routes.py; this class is not used.
    """

    def __init__(
        self,
        device_source="auto",
        board_id=38,
        mac_address=None,
        serial_number=None,
        serial_port=None,
        stream_name=None,
        timeout=15,
        stream_buffer_size=45000,
        other_info=None,
        lsl_stream_type="EEG",
        ppg_stream_name=None,
        ppg_lsl_stream_type="PPG",
        lsl_resolve_timeout=3.0,
    ):
        self.board = None
        self.inlet: Optional[object] = None
        self.ppg_inlet: Optional[object] = None
        self.device_source = (device_source or "auto").lower()
        self.active_source: Optional[str] = None
        self.board_id = int(board_id)
        self.sampling_rate: Optional[int] = None
        self.heart_sampling_rate: Optional[int] = None
        self.eeg_channels: Optional[int] = None
        self.mac_address = mac_address
        self.serial_number = serial_number
        self.serial_port = serial_port
        self.stream_name = stream_name
        self.timeout = timeout
        self.stream_buffer_size = int(stream_buffer_size)
        self.other_info = other_info
        self.lsl_stream_type = lsl_stream_type
        self.ppg_stream_name = ppg_stream_name
        self.ppg_lsl_stream_type = ppg_lsl_stream_type
        self.lsl_resolve_timeout = float(lsl_resolve_timeout)
        self.eeg_channel_indexes: list[int] = []
        self.ppg_channel_indexes: list[int] = []
        self.ecg_channel_indexes: list[int] = []
        self.analog_channel_indexes: list[int] = []
        self.heart_channel_indexes: list[int] = []
        self.heart_signal_source: Optional[str] = None

        # muselsl-specific state
        self._muselsl_thread: Optional[threading.Thread] = None

    # =========================================================================
    # Internal helpers
    # =========================================================================

    def _safe_get_channels(self, resolver) -> list[int]:
        try:
            return list(resolver(self.board_id))
        except Exception:
            return []

    def _get_bluemuse_channel_indexes(self, channel_count: int) -> list[int]:
        if channel_count <= 0:
            return []
        return list(range(min(channel_count, 5)))

    def _build_input_params(self):
        params = BrainFlowInputParams()
        if self.mac_address:
            params.mac_address = self.mac_address
        if self.serial_number:
            params.serial_number = self.serial_number
        if self.serial_port:
            params.serial_port = self.serial_port
        if self.timeout is not None:
            params.timeout = int(self.timeout)
        if self.other_info:
            params.other_info = self.other_info
        return params

    def _build_connection_error(self, error: Exception) -> BrainFlowError:
        exit_code = getattr(error, "exit_code", BrainFlowExitCodes.GENERAL_ERROR.value)
        hints = []

        if self.board_id == BoardIds.MUSE_2_BOARD.value:
            hints.append(
                "Muse 2 native BLE requires Windows 10 build 19041+ or newer and the headset paired in Windows Bluetooth settings."
            )
            if not self.mac_address and not self.serial_number:
                hints.append(
                    "If autodiscovery fails, provide mac_address or serial_number in the session payload."
                )
            hints.append(
                "Keep the headset awake and make sure BlueMuse, Muse app, or any other BLE client is not already connected unless you intentionally use device_source='bluemuse' or 'auto'."
            )
        elif self.board_id == BoardIds.MUSE_2_BLED_BOARD.value:
            if not self.serial_port:
                hints.append(
                    "Muse 2 BLED mode requires the BLED112 dongle COM port in serial_port, for example COM3."
                )
            else:
                hints.append(
                    f"Verify the BLED112 dongle is available on {self.serial_port} and not in use by another process."
                )
        elif self.board_id == BoardIds.MUSE_S_BOARD.value:
            hints.append(
                "Muse S native BLE requires Windows 10 build 19041+ or newer and the headset paired in Windows Bluetooth settings."
            )
        elif self.board_id == BoardIds.MUSE_S_BLED_BOARD.value:
            hints.append(
                "Muse S BLED mode requires the BLED112 dongle COM port in serial_port."
            )

        hint_suffix = f" {' '.join(hints)}" if hints else ""
        return BrainFlowError(f"{error}.{hint_suffix}".strip(), int(exit_code))

    def _resolve_lsl_stream(self, stream_type: str, stream_name: str | None = None):
        streams = resolve_byprop("type", stream_type, timeout=self.lsl_resolve_timeout)
        if stream_name:
            streams = [s for s in streams if s.name() == stream_name]
        return streams[0] if streams else None

    # =========================================================================
    # Connection back-ends
    # =========================================================================

    def _connect_brainflow(self):
        logger.info("Preparing BrainFlow board %s", self.board_id)
        self.board = BoardShim(self.board_id, self._build_input_params())

        try:
            self.board.prepare_session()
            self.board.start_stream(self.stream_buffer_size, "")
            self.sampling_rate = BoardShim.get_sampling_rate(self.board_id)
            self.eeg_channel_indexes = list(BoardShim.get_eeg_channels(self.board_id))
            self.ppg_channel_indexes = self._safe_get_channels(BoardShim.get_ppg_channels)
            self.ecg_channel_indexes = self._safe_get_channels(BoardShim.get_ecg_channels)
            self.analog_channel_indexes = self._safe_get_channels(BoardShim.get_analog_channels)
            if self.ppg_channel_indexes:
                self.heart_channel_indexes = self.ppg_channel_indexes
                self.heart_signal_source = "ppg"
            elif self.ecg_channel_indexes:
                self.heart_channel_indexes = self.ecg_channel_indexes
                self.heart_signal_source = "ecg"
            elif self.analog_channel_indexes:
                self.heart_channel_indexes = self.analog_channel_indexes
                self.heart_signal_source = "analog"
            self.eeg_channels = len(self.eeg_channel_indexes)
            self.active_source = "brainflow"
        except Exception as exc:
            self.disconnect()
            raise self._build_connection_error(exc) from exc

        logger.info(
            "Connected via BrainFlow  sampling_rate=%s  eeg_channels=%s",
            self.sampling_rate,
            self.eeg_channels,
        )
        return True

    def _connect_bluemuse(self):
        if StreamInlet is None or resolve_byprop is None:
            raise MuseConnectionError(
                "BlueMuse mode requires pylsl. Install with: pip install pylsl",
                status_code=500,
            )

        logger.info(
            "Resolving BlueMuse LSL EEG stream  type=%s  name=%s",
            self.lsl_stream_type, self.stream_name,
        )
        eeg_stream = self._resolve_lsl_stream(self.lsl_stream_type, self.stream_name)

        if eeg_stream is None:
            name_hint = f" named '{self.stream_name}'" if self.stream_name else ""
            raise MuseConnectionError(
                f"No BlueMuse LSL EEG stream found{name_hint}. "
                "Start BlueMuse, enable its EEG LSL stream, and keep it connected to the headset.",
                status_code=400,
            )

        self.inlet = StreamInlet(eeg_stream)
        stream_info = self.inlet.info()
        nominal_rate = stream_info.nominal_srate()
        self.sampling_rate = int(nominal_rate) if nominal_rate else 256
        self.eeg_channels = int(stream_info.channel_count())
        self.eeg_channel_indexes = self._get_bluemuse_channel_indexes(self.eeg_channels)

        ppg_stream = self._resolve_lsl_stream(self.ppg_lsl_stream_type, self.ppg_stream_name)
        if ppg_stream is not None:
            self.ppg_inlet = StreamInlet(ppg_stream)
            ppg_info = self.ppg_inlet.info()
            nominal_ppg_rate = ppg_info.nominal_srate()
            self.heart_sampling_rate = int(nominal_ppg_rate) if nominal_ppg_rate else self.sampling_rate
            self.heart_signal_source = "bluemuse-ppg"
            logger.info(
                "Connected to BlueMuse PPG stream  type=%s  name=%s  fs=%s  ch=%s",
                self.ppg_lsl_stream_type, ppg_stream.name(),
                self.heart_sampling_rate, ppg_info.channel_count(),
            )
        else:
            self.ppg_inlet = None
            self.heart_sampling_rate = None
            self.heart_signal_source = None

        self.active_source = "bluemuse"
        logger.info(
            "Connected via BlueMuse LSL  fs=%s  ch=%s  indexes=%s",
            self.sampling_rate, self.eeg_channels, self.eeg_channel_indexes,
        )
        return True

    def _connect_muselsl(self):
        """
        Pure-Python BLE path using the muselsl package.

        Steps
        -----
        1. Scan for nearby Muse headsets with muselsl.list_muses().
        2. Start muselsl.stream() in a daemon thread — it opens a BLE connection
           and publishes an LSL outlet named "Muse" with type "EEG".
        3. Wait for the outlet to appear, then open a PyLSL StreamInlet.

        On Windows Python ≥ 3.10, the ProactorEventLoop is the default but
        Bleak (used internally by muselsl) works fine with it.  If not, we
        fall back to the SelectorEventLoop inside the worker thread.
        """
        try:
            from muselsl import list_muses, stream as muselsl_stream
        except ImportError:
            raise MuseConnectionError(
                "muselsl is not installed. Run: pip install muselsl",
                status_code=500,
            )

        if StreamInlet is None or resolve_byprop is None:
            raise MuseConnectionError(
                "pylsl is required. Run: pip install pylsl",
                status_code=500,
            )

        # ── 1. Discover device ────────────────────────────────────────────
        address = self.mac_address
        device_name = "Muse"

        if not address:
            logger.info("muselsl: scanning for nearby Muse headsets (%.0f s)…",
                        self.timeout or 5)
            try:
                from config import settings
                scan_timeout = settings.muselsl_scan_timeout
            except Exception:
                scan_timeout = 5.0

            try:
                muses = list_muses(timeout=scan_timeout)
            except Exception as exc:
                raise MuseConnectionError(
                    f"muselsl BLE scan failed: {exc}. "
                    "Make sure Bluetooth is enabled and the headset is powered on.",
                    status_code=400,
                ) from exc

            if not muses:
                raise MuseConnectionError(
                    "muselsl found no nearby Muse headsets. "
                    "Power the headset on, keep it within 1 m, and ensure no other "
                    "app (BlueMuse, Muse app) already holds the BLE connection. "
                    "Tip: supply the MAC address in the session payload to skip scanning.",
                    status_code=400,
                )

            address    = muses[0]["address"]
            device_name = muses[0].get("name", "Muse")
            logger.info("muselsl: found %s  %s", device_name, address)

        # ── 2. Start stream thread (skip if one is already alive) ─────────
        if self._muselsl_thread is not None and self._muselsl_thread.is_alive():
            logger.info("muselsl: stream thread already running — reusing existing outlet")
        else:
            logger.info("muselsl: starting stream thread for %s…", address)

            _address = address  # capture for closure

            def _stream_worker():
                try:
                    # On Windows, prefer SelectorEventLoop inside the thread to
                    # avoid conflicts with the main Proactor loop.
                    if sys.platform == "win32":
                        import asyncio
                        asyncio.set_event_loop_policy(
                            asyncio.WindowsSelectorEventLoopPolicy()
                        )
                    muselsl_stream(
                        address=_address,
                        ppg_enabled=False,
                        acc_enabled=False,
                        gyro_enabled=False,
                    )
                except Exception as exc:
                    logger.error("muselsl stream thread exited: %s", exc)

            self._muselsl_thread = threading.Thread(
                target=_stream_worker,
                daemon=True,
                name="muselsl-stream",
            )
            self._muselsl_thread.start()

            try:
                from config import settings
                settle = settings.muselsl_settle_seconds
                resolve_timeout = settings.muselsl_lsl_resolve_timeout
            except Exception:
                settle = 4.0
                resolve_timeout = 8.0

            logger.info("muselsl: waiting %.0f s for BLE negotiation…", settle)
            time.sleep(settle)

            # Widen the LSL resolve timeout for the muselsl outlet
            saved_resolve = self.lsl_resolve_timeout
            self.lsl_resolve_timeout = resolve_timeout

        # ── 3. Resolve LSL outlet ─────────────────────────────────────────
        # muselsl publishes type="EEG" name="Muse" (or custom name)
        eeg_stream = self._resolve_lsl_stream(
            self.lsl_stream_type,
            self.stream_name or "Muse",
        )

        try:
            self.lsl_resolve_timeout = saved_resolve  # type: ignore[possibly-undefined]
        except NameError:
            pass

        if eeg_stream is None:
            raise MuseConnectionError(
                "muselsl started but no LSL EEG stream appeared. "
                "The headset may have disconnected during BLE negotiation — "
                "ensure it is awake and try again.",
                status_code=400,
            )

        # ── 4. Open LSL inlet ─────────────────────────────────────────────
        self.inlet = StreamInlet(eeg_stream)
        stream_info = self.inlet.info()
        self.sampling_rate       = int(stream_info.nominal_srate() or 256)
        self.eeg_channels        = int(stream_info.channel_count())
        self.eeg_channel_indexes = self._get_bluemuse_channel_indexes(self.eeg_channels)
        self.heart_signal_source = None   # muselsl doesn't expose PPG by default
        self.active_source       = "muselsl"

        logger.info(
            "Connected via muselsl  device=%s  address=%s  fs=%d Hz  ch=%d  indexes=%s",
            device_name, address,
            self.sampling_rate, self.eeg_channels, self.eeg_channel_indexes,
        )
        return True

    def _connect_auto(self):
        bluemuse_error = None

        try:
            return self._connect_bluemuse()
        except MuseConnectionError as exc:
            bluemuse_error = exc

        try:
            return self._connect_brainflow()
        except BrainFlowError as exc:
            raise MuseConnectionError(
                f"BlueMuse LSL failed: {bluemuse_error}. "
                f"BrainFlow fallback also failed: {exc}. "
                "If you have muselsl installed, try device_source='muselsl'. "
                "If you use BlueMuse, enable its EEG LSL stream. "
                "If you want direct BrainFlow BLE, close BlueMuse first.",
                status_code=400,
            ) from exc

    # =========================================================================
    # Public interface
    # =========================================================================

    @staticmethod
    def discover_muses(timeout: float = 5.0) -> list[dict]:
        """
        Scan for nearby Muse headsets using muselsl's BLE advertisement scan.

        Returns a list of dicts, each with 'name' and 'address' keys.
        Returns an empty list when muselsl is not installed or no headsets are found.
        """
        try:
            from muselsl import list_muses
            result = list_muses(timeout=timeout)
            return result or []
        except ImportError:
            logger.warning("discover_muses: muselsl not installed (pip install muselsl)")
            return []
        except Exception as exc:
            logger.warning("discover_muses: scan failed: %s", exc)
            return []

    def is_connected(self) -> bool:
        if self.active_source in ("bluemuse", "muselsl"):
            return self.inlet is not None

        return self.board is not None and self.board.is_prepared()

    def connect(self):
        """Connect to the configured EEG source."""
        self.disconnect()

        if self.device_source == "brainflow":
            return self._connect_brainflow()

        if self.device_source == "bluemuse":
            return self._connect_bluemuse()

        if self.device_source == "muselsl":
            return self._connect_muselsl()

        if self.device_source == "auto":
            return self._connect_auto()

        raise MuseConnectionError(
            f"Unsupported device_source '{self.device_source}'. "
            "Valid values: 'auto', 'brainflow', 'bluemuse', 'muselsl'.",
            status_code=400,
        )

    def get_eeg_data(self, window_size: int = 256):
        """
        Retrieve the latest EEG window.

        Returns
        -------
        ndarray of shape (samples, channels) — samples-major.
        Returns None when insufficient data is available.
        """
        if self.active_source in ("bluemuse", "muselsl"):
            if self.inlet is None:
                return None

            samples, _ = self.inlet.pull_chunk(timeout=0.25, max_samples=int(window_size))
            if not samples or len(samples) < 64:
                return None

            sample_array = np.asarray(samples, dtype=np.float64)
            if sample_array.ndim == 1:
                sample_array = sample_array.reshape(-1, 1)

            if sample_array.ndim != 2:
                return None

            if self.eeg_channel_indexes:
                valid = [i for i in self.eeg_channel_indexes if i < sample_array.shape[1]]
                if not valid:
                    return None
                sample_array = sample_array[:, valid]

            finite_mask = np.all(np.isfinite(sample_array), axis=1)
            sample_array = sample_array[finite_mask]
            if sample_array.shape[0] < 64 or sample_array.shape[1] == 0:
                return None

            return sample_array

        # BrainFlow path
        if not self.is_connected():
            return None

        available = self.board.get_board_data_count()
        if available <= 0:
            return None

        sample_count = min(int(window_size), int(available))
        if sample_count < 64:
            return None

        board_data = self.board.get_current_board_data(sample_count)
        if board_data.size == 0 or not self.eeg_channel_indexes:
            return None

        eeg_data = board_data[self.eeg_channel_indexes, :]
        if eeg_data.size == 0:
            return None

        return np.asarray(eeg_data.T, dtype=np.float64)

    def get_heart_signal(self, window_size: int = 512):
        """
        Return a 1-D pulse signal for HeartPy, sample-rate, and source label.
        Returns (None, None, source) when no pulse stream is available.
        """
        if self.active_source in ("bluemuse", "muselsl"):
            if self.ppg_inlet is None:
                return None, None, self.heart_signal_source

            samples, _ = self.ppg_inlet.pull_chunk(timeout=0.25, max_samples=int(window_size))
            if not samples or len(samples) < 64:
                return None, None, self.heart_signal_source

            sample_array = np.asarray(samples, dtype=np.float64)
            if sample_array.ndim == 1:
                sample_array = sample_array.reshape(-1, 1)

            if sample_array.ndim != 2:
                return None, None, self.heart_signal_source

            finite_mask = np.all(np.isfinite(sample_array), axis=1)
            sample_array = sample_array[finite_mask]
            if sample_array.shape[0] < 64 or sample_array.shape[1] == 0:
                return None, None, self.heart_signal_source

            signal = np.mean(sample_array, axis=1)
            return (
                signal,
                int(self.heart_sampling_rate or self.sampling_rate or 0),
                self.heart_signal_source,
            )

        # BrainFlow path
        if not self.is_connected() or not self.heart_channel_indexes:
            return None, None, self.heart_signal_source

        available = self.board.get_board_data_count()
        if available <= 0:
            return None, None, self.heart_signal_source

        sample_count = min(int(window_size), int(available))
        if sample_count < 64:
            return None, None, self.heart_signal_source

        board_data = self.board.get_current_board_data(sample_count)
        if board_data.size == 0:
            return None, None, self.heart_signal_source

        signal = np.asarray(board_data[self.heart_channel_indexes[0], :], dtype=np.float64)
        signal = signal[np.isfinite(signal)]
        if signal.size < 64:
            return None, None, self.heart_signal_source

        return signal, int(self.sampling_rate or 0), self.heart_signal_source

    def get_runtime_diagnostics(self) -> dict:
        diagnostics: dict = {
            "device_source": self.device_source,
            "active_source": self.active_source,
            "sampling_rate": self.sampling_rate,
            "heart_sampling_rate": self.heart_sampling_rate,
            "eeg_channels": self.eeg_channels,
            "eeg_channel_indexes": self.eeg_channel_indexes,
            "heart_signal_source": self.heart_signal_source,
            "heart_channel_indexes": self.heart_channel_indexes,
        }

        if self.active_source in ("bluemuse", "muselsl"):
            diagnostics["inlet_ready"]     = self.inlet is not None
            diagnostics["ppg_inlet_ready"] = self.ppg_inlet is not None
            if self.active_source == "muselsl":
                diagnostics["muselsl_thread_alive"] = (
                    self._muselsl_thread is not None and self._muselsl_thread.is_alive()
                )
            return diagnostics

        # BrainFlow
        board = self.board
        diagnostics["board_ready"] = board is not None
        if board is not None:
            try:
                diagnostics["board_prepared"] = bool(board.is_prepared())
            except Exception as exc:
                diagnostics["board_prepared_error"] = str(exc)
            try:
                diagnostics["available_samples"] = int(board.get_board_data_count())
            except Exception as exc:
                diagnostics["available_samples_error"] = str(exc)

        return diagnostics

    def disconnect(self):
        """Stop streaming and release all resources."""
        had_session = (
            self.board is not None
            or self.inlet is not None
            or self.ppg_inlet is not None
        )

        # BrainFlow teardown
        if self.board is not None:
            try:
                if self.board.is_prepared():
                    try:
                        self.board.stop_stream()
                    except Exception:
                        pass
                    self.board.release_session()
            finally:
                self.board = None

        # LSL inlet teardown (BlueMuse + muselsl)
        if self.inlet is not None:
            try:
                self.inlet.close_stream()
            except Exception:
                pass
            self.inlet = None

        if self.ppg_inlet is not None:
            try:
                self.ppg_inlet.close_stream()
            except Exception:
                pass
            self.ppg_inlet = None

        # muselsl stream thread — it's a daemon thread so the OS will clean it
        # up on process exit.  We don't forcibly kill it here because the outlet
        # may still be useful if connect() is called again in the same process
        # (the thread check in _connect_muselsl() will reuse the live outlet).
        if self._muselsl_thread is not None and not self._muselsl_thread.is_alive():
            self._muselsl_thread = None

        self.active_source       = None
        self.heart_sampling_rate = None
        self.heart_signal_source = None
        self.heart_channel_indexes = []

        if had_session:
            logger.info("EEG stream disconnected")
