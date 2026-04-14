"""
Signal Processing Layer
Filters raw EEG and extracts frequency-band power (alpha, beta, theta).
"""

import numpy as np
from scipy.signal import butter, sosfilt, welch

# Sampling rate of the Muse headband
SAMPLE_RATE = 256  # Hz

# Band definitions (Hz)
BANDS = {
    "theta": (4, 7),
    "alpha": (8, 12),
    "beta":  (13, 30),
}


def bandpass_filter(data: np.ndarray, low: float, high: float, fs: int = SAMPLE_RATE) -> np.ndarray:
    """Apply a 4th-order Butterworth band-pass filter."""
    sos = butter(4, [low, high], btype="bandpass", fs=fs, output="sos")
    return sosfilt(sos, data)


def extract_band_power(signal: np.ndarray, low: float, high: float, fs: int = SAMPLE_RATE) -> float:
    """Compute mean power in a frequency band using Welch's method."""
    freqs, psd = welch(signal, fs=fs, nperseg=min(len(signal), fs * 2))
    band_mask = (freqs >= low) & (freqs <= high)
    if not np.any(band_mask):
        return 0.0
    return float(np.mean(psd[band_mask]))


def process(raw_samples: list[list[float]]) -> dict[str, float]:
    """
    Process a buffer of raw EEG samples.

    Args:
        raw_samples: list of [ch0, ch1, ch2, ch3] readings

    Returns:
        dict with normalized band powers: {"alpha": float, "beta": float, "theta": float}
    """
    if len(raw_samples) < 32:
        return {"alpha": 0.0, "beta": 0.0, "theta": 0.0}

    # Use the mean across available channels
    arr = np.array(raw_samples)  # shape: (n_samples, n_channels)
    signal = arr.mean(axis=1)

    # Band-pass whole signal first (1–50 Hz)
    signal = bandpass_filter(signal, 1.0, 50.0)

    powers = {}
    for band, (low, high) in BANDS.items():
        powers[band] = extract_band_power(signal, low, high)

    # Normalize so bands sum to 1 (relative power)
    total = sum(powers.values()) or 1.0
    return {band: round(p / total, 4) for band, p in powers.items()}
