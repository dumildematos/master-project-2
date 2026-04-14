"""
Design Mapping Layer
Translates emotional states into visual design parameters sent to TouchDesigner.

Parameter ranges:
  colorHue        0–360   (hue of the dominant garment color)
  flowSpeed       0.0–1.0 (animation speed of cloth simulation)
  distortion      0.0–1.0 (noise-based mesh deformation intensity)
  particleDensity 0.0–1.0 (density of particle system overlay)
  brightness      0.0–1.0 (overall luminance)
"""

from dataclasses import dataclass

from emotion_engine import EmotionResult


@dataclass
class DesignParams:
    colorHue: float
    flowSpeed: float
    distortion: float
    particleDensity: float
    brightness: float

    def to_dict(self) -> dict:
        return {
            "colorHue":        round(self.colorHue, 2),
            "flowSpeed":       round(self.flowSpeed, 3),
            "distortion":      round(self.distortion, 3),
            "particleDensity": round(self.particleDensity, 3),
            "brightness":      round(self.brightness, 3),
        }


# Static mapping: emotion → base design parameters
_EMOTION_MAP: dict[str, DesignParams] = {
    "calm":       DesignParams(colorHue=210, flowSpeed=0.20, distortion=0.10, particleDensity=0.30, brightness=0.70),
    "meditative": DesignParams(colorHue=270, flowSpeed=0.10, distortion=0.05, particleDensity=0.20, brightness=0.50),
    "focused":    DesignParams(colorHue=40,  flowSpeed=0.60, distortion=0.30, particleDensity=0.60, brightness=0.90),
    "stressed":   DesignParams(colorHue=0,   flowSpeed=0.90, distortion=0.70, particleDensity=0.80, brightness=0.95),
    "drowsy":     DesignParams(colorHue=180, flowSpeed=0.05, distortion=0.03, particleDensity=0.10, brightness=0.40),
    "neutral":    DesignParams(colorHue=120, flowSpeed=0.35, distortion=0.20, particleDensity=0.40, brightness=0.65),
}


def map_to_params(result: EmotionResult) -> DesignParams:
    """
    Return design parameters for the given emotion result.
    Scales parameters by confidence so lower-confidence readings
    trend toward neutral defaults.
    """
    base = _EMOTION_MAP.get(result.emotion, _EMOTION_MAP["neutral"])
    neutral = _EMOTION_MAP["neutral"]
    c = result.confidence

    return DesignParams(
        colorHue        = base.colorHue,  # hue is not interpolated
        flowSpeed       = _lerp(neutral.flowSpeed,       base.flowSpeed,       c),
        distortion      = _lerp(neutral.distortion,      base.distortion,      c),
        particleDensity = _lerp(neutral.particleDensity, base.particleDensity, c),
        brightness      = _lerp(neutral.brightness,      base.brightness,      c),
    )


def _lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t
