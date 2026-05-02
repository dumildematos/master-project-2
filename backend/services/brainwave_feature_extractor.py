"""
brainwave_feature_extractor.py
-------------------------------
Transforms raw EEG band powers into a richer feature vector for ML training
and inference.

Maintains a sliding window (deque) so rolling statistics (mean, variance,
stability) are computed over the last N frames rather than a single snapshot.
"""
import math
from collections import deque
from typing import Dict, Optional

_WINDOW_SIZE = 10   # ~5 s at 2 Hz sample rate
_EPS = 1e-8

_BANDS = ("alpha", "beta", "theta", "gamma", "delta")


class BrainwaveFeatureExtractor:
    """
    Stateful feature extractor — call extract() once per EEG frame.

    Thread-safety: not thread-safe; each stream path should own its own
    instance (the singleton below is fine for the single background thread).
    """

    def __init__(self, window_size: int = _WINDOW_SIZE):
        self._window: deque[Dict[str, float]] = deque(maxlen=window_size)

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def extract(
        self,
        bands: Dict[str, float],
        baseline: Optional[Dict[str, float]] = None,
    ) -> Dict[str, float]:
        """
        Return a flat feature dict ready to feed into scikit-learn.

        Parameters
        ----------
        bands:    raw band powers from signal processing (alpha, beta, …)
        baseline: optional per-user mean bands from calibration for normalisation
        """
        self._window.append(bands)

        alpha = bands.get("alpha", 0.0)
        beta  = bands.get("beta",  0.0)
        theta = bands.get("theta", 0.0)
        gamma = bands.get("gamma", 0.0)
        delta = bands.get("delta", 0.0)

        features: Dict[str, float] = {}

        # Raw bands
        for b in _BANDS:
            features[b] = bands.get(b, 0.0)

        # Ratio features
        features["alpha_beta_ratio"]  = alpha / (beta  + _EPS)
        features["theta_alpha_ratio"] = theta / (alpha + _EPS)
        features["beta_theta_ratio"]  = beta  / (theta + _EPS)
        features["gamma_beta_ratio"]  = gamma / (beta  + _EPS)

        # Rolling statistics over the sliding window
        window_list = list(self._window)
        features["rolling_mean_alpha"] = _mean(window_list, "alpha")
        features["rolling_mean_beta"]  = _mean(window_list, "beta")
        features["rolling_mean_theta"] = _mean(window_list, "theta")
        features["beta_variance"]      = _variance(window_list, "beta")
        features["alpha_variance"]     = _variance(window_list, "alpha")

        # Signal stability: low std of alpha = stable / clean signal
        alpha_std = math.sqrt(features["alpha_variance"])
        features["signal_stability"] = max(0.0, 1.0 - alpha_std * 5.0)

        # Baseline-normalised features (zero if no baseline)
        if baseline:
            for b in _BANDS:
                bval  = bands.get(b, 0.0)
                bmean = baseline.get(f"{b}_mean", 0.0)
                features[f"{b}_norm"] = bval - bmean
        else:
            for b in _BANDS:
                features[f"{b}_norm"] = 0.0

        return features

    def reset(self) -> None:
        self._window.clear()

    @staticmethod
    def feature_names() -> list[str]:
        """Ordered list of feature names — must match the order in to_vector()."""
        bands = list(_BANDS)
        ratio_names = [
            "alpha_beta_ratio", "theta_alpha_ratio",
            "beta_theta_ratio", "gamma_beta_ratio",
        ]
        rolling_names = [
            "rolling_mean_alpha", "rolling_mean_beta", "rolling_mean_theta",
            "beta_variance", "alpha_variance", "signal_stability",
        ]
        norm_names = [f"{b}_norm" for b in _BANDS]
        return bands + ratio_names + rolling_names + norm_names

    @staticmethod
    def to_vector(features: Dict[str, float]) -> list[float]:
        """Return features as an ordered list for numpy / sklearn consumption."""
        return [features.get(k, 0.0) for k in BrainwaveFeatureExtractor.feature_names()]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _mean(window: list[Dict[str, float]], key: str) -> float:
    vals = [f.get(key, 0.0) for f in window]
    return sum(vals) / len(vals) if vals else 0.0


def _variance(window: list[Dict[str, float]], key: str) -> float:
    vals = [f.get(key, 0.0) for f in window]
    if len(vals) < 2:
        return 0.0
    mu = sum(vals) / len(vals)
    return sum((v - mu) ** 2 for v in vals) / len(vals)


# Module-level singleton used by the stream pipeline
feature_extractor = BrainwaveFeatureExtractor()
