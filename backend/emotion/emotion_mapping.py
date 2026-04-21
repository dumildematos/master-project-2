from typing import Dict, Optional
from models.schemas import EmotionType


class EmotionMapper:
    """
    Maps EEG band features to emotional states.
    Uses a rule-based heuristic suitable for real-time demos.
    """

    def __init__(self):
        self.focus_threshold = 0.65
        self.rest_threshold = 0.65
        self.stress_threshold = 0.35
        self.focus_beta_min = 0.32
        self.focus_beta_margin = 0.06
        self.relaxed_alpha_min = 0.3
        self.excited_gamma_margin = 0.04

    def detect_emotion(
        self,
        eeg_features: Dict[str, float],
        mindfulness: Optional[float] = None,
        restfulness: Optional[float] = None,
    ) -> Dict:
        """
        Determine emotional state from BrainFlow metrics and EEG band ratios.
        """

        alpha = eeg_features.get("alpha", 0.0)
        beta = eeg_features.get("beta", 0.0)
        gamma = eeg_features.get("gamma", 0.0)
        theta = eeg_features.get("theta", 0.0)

        beta_advantage = beta - alpha
        alpha_advantage = alpha - beta

        emotion = EmotionType.calm
        confidence = 0.5

        if (
            mindfulness is not None
            and restfulness is not None
            and mindfulness >= self.focus_threshold
            and restfulness >= self.rest_threshold
        ):
            emotion = EmotionType.calm
            confidence = (mindfulness + restfulness) / 2
        elif restfulness is not None and restfulness >= self.rest_threshold and alpha >= beta:
            emotion = EmotionType.relaxed
            confidence = max(restfulness, alpha)
        elif (
            mindfulness is not None
            and mindfulness >= self.focus_threshold
            and beta >= self.focus_beta_min
            and beta_advantage >= self.focus_beta_margin
        ):
            emotion = EmotionType.focused
            confidence = max(mindfulness, beta)
        elif (
            gamma > beta
            and gamma > alpha
            and gamma - max(beta, alpha) >= self.excited_gamma_margin
            and (restfulness is None or restfulness < self.rest_threshold)
        ):
            emotion = EmotionType.excited
            confidence = gamma
        elif restfulness is not None and restfulness < self.stress_threshold and beta >= alpha:
            emotion = EmotionType.stressed
            confidence = max(1.0 - restfulness, beta)
        elif alpha >= self.relaxed_alpha_min and alpha_advantage >= self.focus_beta_margin:
            emotion = EmotionType.relaxed if theta >= 0.16 else EmotionType.calm
            confidence = max(alpha, restfulness or 0.0)
        elif alpha > beta:
            emotion = EmotionType.calm
            confidence = alpha
        elif beta >= self.focus_beta_min and beta_advantage >= self.focus_beta_margin:
            emotion = EmotionType.focused
            confidence = beta
        elif theta > alpha and theta > beta:
            emotion = EmotionType.relaxed
            confidence = theta

        return {
            "emotion": emotion,
            "confidence": round(min(max(confidence, 0.0), 1.0), 3)
        }