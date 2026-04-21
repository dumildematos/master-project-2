import { useState, useCallback } from "react";
import type { SentioState } from "./useWebSocket";
import { resolveApiBaseUrl } from "../lib/runtimeConfig";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------
export interface ManualBands {
  alpha: number;
  beta: number;
  theta: number;
  gamma: number;
  delta: number;
  confidence: number;
}

export type EmotionKey =
  | "calm"
  | "focused"
  | "stressed"
  | "relaxed"
  | "excited";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const EMOTION_HUE: Record<EmotionKey, number> = {
  calm: 210,
  focused: 40,
  stressed: 0,
  relaxed: 180,
  excited: 285,
};

const EMOTION_GUIDANCE: Record<EmotionKey, string> = {
  calm: "Manual override — calm state active. Slow, wide drifting forms.",
  focused:
    "Manual override — focused state active. Sharp, structured patterns.",
  stressed:
    "Manual override — stressed state active. Rapid fragmented turbulence.",
  relaxed: "Manual override — relaxed state active. Soft, slow-moving shapes.",
  excited:
    "Manual override — excited state active. Fast, vivid bursting forms.",
};

export const EMOTION_PRESETS: Record<EmotionKey, ManualBands> = {
  calm: {
    alpha: 0.68,
    beta: 0.18,
    theta: 0.16,
    gamma: 0.06,
    delta: 0.05,
    confidence: 0.84,
  },
  focused: {
    alpha: 0.32,
    beta: 0.72,
    theta: 0.1,
    gamma: 0.14,
    delta: 0.03,
    confidence: 0.91,
  },
  stressed: {
    alpha: 0.22,
    beta: 0.88,
    theta: 0.08,
    gamma: 0.18,
    delta: 0.04,
    confidence: 0.76,
  },
  relaxed: {
    alpha: 0.75,
    beta: 0.12,
    theta: 0.45,
    gamma: 0.05,
    delta: 0.08,
    confidence: 0.88,
  },
  excited: {
    alpha: 0.4,
    beta: 0.65,
    theta: 0.12,
    gamma: 0.32,
    delta: 0.04,
    confidence: 0.87,
  },
};

const DEFAULT_BANDS: ManualBands = EMOTION_PRESETS.calm;

// ---------------------------------------------------------------------------
// Build a SentioState from manual band values
// ---------------------------------------------------------------------------
function buildManualState(
  bands: ManualBands,
  emotion: EmotionKey,
): SentioState {
  const { alpha, beta, theta, gamma, delta, confidence } = bands;
  const hue = EMOTION_HUE[emotion];
  return {
    bands: { alpha, beta, theta, gamma, delta },
    emotion,
    confidence,
    detectedEmotion: emotion,
    detectedConfidence: confidence,
    isUncertain: false,   // manual mode is always intentional — never uncertain
    mindfulness: null,
    restfulness: null,
    signal_quality: confidence * 100,
    vitals: {
      heartBpm: null,
      heartConfidence: null,
      respirationRpm: null,
      respirationConfidence: null,
      source: null,
    },
    params: {
      colorHue: hue,
      flowSpeed: parseFloat((beta * 0.75 + (1 - alpha) * 0.25).toFixed(3)),
      distortion: parseFloat((gamma * 0.6 + beta * 0.4).toFixed(3)),
      particleDensity: parseFloat(
        (alpha * 0.65 + confidence * 0.35).toFixed(3),
      ),
      brightness: parseFloat(
        Math.min(1, 0.3 + alpha * 0.45 + (1 - theta) * 0.25).toFixed(3),
      ),
    },
    guidance: EMOTION_GUIDANCE[emotion],
  };
}

// ---------------------------------------------------------------------------
// Send manual values to backend → Arduino via WebSocket stream
// ---------------------------------------------------------------------------
async function sendToBackend(
  bands: ManualBands,
  emotion: EmotionKey,
): Promise<void> {
  const apiUrl = resolveApiBaseUrl();
  try {
    await fetch(`${apiUrl}/api/manual/override`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        alpha: bands.alpha,
        beta: bands.beta,
        theta: bands.theta,
        gamma: bands.gamma,
        delta: bands.delta,
        confidence: bands.confidence,
        emotion,
      }),
    });
  } catch {
    // Backend may be unreachable — UI still works locally
  }
}

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------
export function useManualMode() {
  const [isManual, setIsManual] = useState(false);
  const [emotion, setEmotionKey] = useState<EmotionKey>("calm");
  const [bands, setBandsState] = useState<ManualBands>(DEFAULT_BANDS);

  // Computed SentioState from current manual values
  const manualData = buildManualState(bands, emotion);

  // Update a single band slider (live — no backend call until commit)
  const setBand = useCallback((key: keyof ManualBands, value: number) => {
    setBandsState((prev) => ({ ...prev, [key]: value }));
  }, []);

  // Set an emotion preset — fills all sliders and pushes to backend
  const setEmotion = useCallback((emo: EmotionKey) => {
    const preset = EMOTION_PRESETS[emo];
    setEmotionKey(emo);
    setBandsState(preset);
    sendToBackend(preset, emo);
  }, []);

  // Reset to calm defaults
  const resetToDefaults = useCallback(() => {
    setEmotionKey("calm");
    setBandsState(EMOTION_PRESETS.calm);
    sendToBackend(EMOTION_PRESETS.calm, "calm");
  }, []);

  // Activate manual mode — snapshot live data into sliders
  const activate = useCallback((liveData: SentioState) => {
    const snapBands: ManualBands = {
      alpha: liveData.bands.alpha,
      beta: liveData.bands.beta,
      theta: liveData.bands.theta,
      gamma: liveData.bands.gamma,
      delta: liveData.bands.delta,
      confidence: liveData.confidence,
    };
    setBandsState(snapBands);
    const emo =
      (liveData.emotion as EmotionKey) in EMOTION_PRESETS
        ? (liveData.emotion as EmotionKey)
        : "calm";
    setEmotionKey(emo);
    setIsManual(true);
  }, []);

  const deactivate = useCallback(() => {
    setIsManual(false);
  }, []);

  // Called when a slider is released — push to backend
  const commitBand = useCallback(
    (key: keyof ManualBands, value: number) => {
      setBandsState((prev) => {
        sendToBackend({ ...prev, [key]: value }, emotion);
        return prev;
      });
    },
    [emotion],
  );

  return {
    isManual,
    manualData,
    emotion,
    bands,
    activate,
    deactivate,
    setEmotion,
    setBand,
    commitBand,
    resetToDefaults,
  };
}
