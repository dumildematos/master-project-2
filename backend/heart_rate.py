import logging

import heartpy as hp
import numpy as np


logger = logging.getLogger("sentio.heart")


class HeartRateProcessor:
    """
    Estimate heart and respiration metrics from a pulse-like waveform using HeartPy.
    """

    def __init__(self, sample_rate: int, window_seconds: float = 12.0):
        self.sample_rate = int(sample_rate)
        self.window_seconds = float(window_seconds)
        self.buffer = np.array([], dtype=np.float64)

    def reset(self, sample_rate: int | None = None):
        if sample_rate is not None:
            self.sample_rate = int(sample_rate)
        self.buffer = np.array([], dtype=np.float64)

    def update(self, signal: np.ndarray | list[float], sample_rate: int | None = None) -> dict | None:
        if sample_rate is not None:
            self.sample_rate = int(sample_rate)

        if self.sample_rate <= 0:
            return None

        samples = np.asarray(signal, dtype=np.float64).flatten()
        samples = samples[np.isfinite(samples)]
        if samples.size == 0:
            return None

        max_samples = max(int(self.sample_rate * self.window_seconds), self.sample_rate * 4)
        self.buffer = np.concatenate((self.buffer, samples))[-max_samples:]

        min_samples = max(self.sample_rate * 4, 256)
        if self.buffer.size < min_samples:
            return None

        try:
            filtered = hp.filter_signal(
                self.buffer,
                cutoff=[0.75, 3.5],
                sample_rate=float(self.sample_rate),
                order=3,
                filtertype="bandpass",
            )
            scaled = hp.scale_data(filtered)
            working_data, measures = hp.process(
                scaled,
                sample_rate=float(self.sample_rate),
                bpmmin=45,
                bpmmax=180,
                high_precision=True,
                reject_segmentwise=False,
                clean_rr=True,
            )
        except Exception as exc:
            logger.debug("HeartPy processing failed: %s", exc)
            return None

        bpm = measures.get("bpm")
        respiration_rate_hz = measures.get("breathingrate")
        if bpm is None or not np.isfinite(bpm):
            return None

        respiration_rpm = None
        if respiration_rate_hz is not None and np.isfinite(respiration_rate_hz):
            respiration_rpm = float(respiration_rate_hz) * 60.0
            if not 4.0 <= respiration_rpm <= 40.0:
                respiration_rpm = None

        peak_count = len(working_data.get("peaklist", []))
        expected_beats = max((float(bpm) / 60.0) * self.window_seconds, 1.0)
        heart_confidence = min(1.0, peak_count / expected_beats)

        respiration_confidence = None
        if respiration_rpm is not None:
            breathing_signal = np.asarray(working_data.get("breathing_signal", []), dtype=np.float64)
            respiration_confidence = 0.0 if breathing_signal.size < 8 else min(1.0, breathing_signal.size / 64.0)

        return {
            "heart_bpm": round(float(bpm), 1),
            "heart_confidence": round(float(heart_confidence), 3),
            "respiration_rpm": None if respiration_rpm is None else round(float(respiration_rpm), 1),
            "respiration_confidence": None if respiration_confidence is None else round(float(respiration_confidence), 3),
        }