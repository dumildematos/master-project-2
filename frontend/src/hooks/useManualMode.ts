import { useState, useCallback, useRef } from "react";
import type { SentioState } from "./useWebSocket";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------
export interface ManualBands {
  alpha:      number;
  beta:       number;
  theta:      number;
  gamma:      number;
  delta:      number;
  confidence: number;
}

export type EmotionKey = "calm" | "focused" | "stressed" | "relaxed" | "excited";

export interface OscMessage {
  address: string;
  value:   string;
  type:    "float" | "string";
  id:      number;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const EMOTION_HUE: Record<EmotionKey, number> = {
  calm:    210,
  focused: 40,
  stressed:0,
  relaxed: 180,
  excited: 285,
};

const EMOTION_GUIDANCE: Record<EmotionKey, string> = {
  calm:    "Manual override — calm state active. Slow, wide drifting forms.",
  focused: "Manual override — focused state active. Sharp, structured patterns.",
  stressed:"Manual override — stressed state active. Rapid fragmented turbulence.",
  relaxed: "Manual override — relaxed state active. Soft, slow-moving shapes.",
  excited: "Manual override — excited state active. Fast, vivid bursting forms.",
};

export const EMOTION_PRESETS: Record<EmotionKey, ManualBands> = {
  calm:    { alpha: 0.68, beta: 0.18, theta: 0.16, gamma: 0.06, delta: 0.05, confidence: 0.84 },
  focused: { alpha: 0.32, beta: 0.72, theta: 0.10, gamma: 0.14, delta: 0.03, confidence: 0.91 },
  stressed:{ alpha: 0.22, beta: 0.88, theta: 0.08, gamma: 0.18, delta: 0.04, confidence: 0.76 },
  relaxed: { alpha: 0.75, beta: 0.12, theta: 0.45, gamma: 0.05, delta: 0.08, confidence: 0.88 },
  excited: { alpha: 0.40, beta: 0.65, theta: 0.12, gamma: 0.32, delta: 0.04, confidence: 0.87 },
};

const DEFAULT_BANDS: ManualBands = EMOTION_PRESETS.calm;

// ---------------------------------------------------------------------------
// Build a SentioState from manual band values
// ---------------------------------------------------------------------------
function buildManualState(bands: ManualBands, emotion: EmotionKey): SentioState {
  const { alpha, beta, theta, gamma, delta, confidence } = bands;
  const hue = EMOTION_HUE[emotion];
  return {
    bands:          { alpha, beta, theta, gamma, delta },
    emotion,
    confidence,
    signal_quality: confidence * 100,
    params: {
      colorHue:        hue,
      flowSpeed:       parseFloat((beta  * 0.75 + (1 - alpha) * 0.25).toFixed(3)),
      distortion:      parseFloat((gamma * 0.6  + beta * 0.4).toFixed(3)),
      particleDensity: parseFloat((alpha * 0.65 + confidence * 0.35).toFixed(3)),
      brightness:      parseFloat(Math.min(1, 0.30 + alpha * 0.45 + (1 - theta) * 0.25).toFixed(3)),
    },
    guidance: EMOTION_GUIDANCE[emotion],
  };
}

// ---------------------------------------------------------------------------
// Send manual values to backend → TouchDesigner
// ---------------------------------------------------------------------------
async function sendToBackend(bands: ManualBands, emotion: EmotionKey): Promise<void> {
  const apiUrl = localStorage.getItem("sentioApiUrl") ?? "http://localhost:8000";
  try {
    await fetch(`${apiUrl}/api/osc/manual`, {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        alpha:      bands.alpha,
        beta:       bands.beta,
        theta:      bands.theta,
        gamma:      bands.gamma,
        delta:      bands.delta,
        confidence: bands.confidence,
        emotion,
      }),
    });
  } catch {
    // Backend endpoint may not exist yet — silent fail, UI still works
  }
}

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------
export function useManualMode() {
  const [isManual,  setIsManual]  = useState(false);
  const [emotion,   setEmotionKey]= useState<EmotionKey>("calm");
  const [bands,     setBandsState]= useState<ManualBands>(DEFAULT_BANDS);
  const [oscMessages, setOscMessages] = useState<OscMessage[]>([]);
  const msgIdRef  = useRef(0);

  // Computed SentioState from current manual values
  const manualData = buildManualState(bands, emotion);

  // Add a message to the OSC log (max 10 visible)
  const logOsc = useCallback((address: string, value: string, type: "float" | "string" = "float") => {
    setOscMessages(prev => [
      { address, value, type, id: ++msgIdRef.current },
      ...prev.slice(0, 9),
    ]);
  }, []);

  // Update a single band slider
  const setBand = useCallback((key: keyof ManualBands, value: number) => {
    setBandsState(prev => {
      const next = { ...prev, [key]: value };
      const addr = key === "confidence" ? "/sentio/confidence" : `/sentio/${key}`;
      return next;
    });
    const addr = key === "confidence" ? "/sentio/confidence" : `/sentio/${key}`;
    logOsc(addr, value.toFixed(3));
  }, [logOsc]);

  // Set an emotion preset — fills all sliders
  const setEmotion = useCallback((emo: EmotionKey) => {
    const preset = EMOTION_PRESETS[emo];
    setEmotionKey(emo);
    setBandsState(preset);
    // Log burst
    logOsc("/sentio/emotion", emo, "string");
    (["alpha","beta","theta","gamma","delta"] as const).forEach(k =>
      logOsc(`/sentio/${k}`, preset[k].toFixed(3))
    );
    logOsc("/sentio/confidence", preset.confidence.toFixed(3));
    sendToBackend(preset, emo);
  }, [logOsc]);

  // Reset to calm defaults
  const resetToDefaults = useCallback(() => {
    setEmotionKey("calm");
    setBandsState(EMOTION_PRESETS.calm);
    logOsc("/sentio/emotion", "calm", "string");
    logOsc("/sentio/alpha", EMOTION_PRESETS.calm.alpha.toFixed(3));
    sendToBackend(EMOTION_PRESETS.calm, "calm");
  }, [logOsc]);

  // Activate manual mode — snapshot live data into sliders
  const activate = useCallback((liveData: SentioState) => {
    const snapBands: ManualBands = {
      alpha:      liveData.bands.alpha,
      beta:       liveData.bands.beta,
      theta:      liveData.bands.theta,
      gamma:      liveData.bands.gamma,
      delta:      liveData.bands.delta,
      confidence: liveData.confidence,
    };
    setBandsState(snapBands);
    const emo = (liveData.emotion as EmotionKey) in EMOTION_PRESETS
      ? (liveData.emotion as EmotionKey)
      : "calm";
    setEmotionKey(emo);
    setOscMessages([]);
    setIsManual(true);
  }, []);

  const deactivate = useCallback(() => {
    setIsManual(false);
    setOscMessages([]);
  }, []);

  // Called when a slider is released — send to backend
  const commitBand = useCallback((key: keyof ManualBands, value: number) => {
    setBandsState(prev => {
      sendToBackend({ ...prev, [key]: value }, emotion);
      return prev;
    });
  }, [emotion]);

  return {
    isManual,
    manualData,
    emotion,
    bands,
    oscMessages,
    activate,
    deactivate,
    setEmotion,
    setBand,
    commitBand,
    resetToDefaults,
  };
}
