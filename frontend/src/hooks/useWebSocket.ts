import { useEffect, useRef, useState } from "react";
import { getEmotionMeta } from "../lib/emotionMeta";
import { resolveBrainStreamUrl } from "../lib/runtimeConfig";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------
export interface SentioState {
  bands: {
    alpha: number;
    beta: number;
    theta: number;
    gamma: number;
    delta: number;
  };
  emotion: string;
  confidence: number;
  /** Raw per-frame emotion before backend smoothing window */
  detectedEmotion: string;
  detectedConfidence: number;
  /** True when confidence < UNCERTAIN_THRESHOLD */
  isUncertain: boolean;
  mindfulness: number | null;
  restfulness: number | null;
  signal_quality: number;
  vitals: {
    heartBpm: number | null;
    heartConfidence: number | null;
    respirationRpm: number | null;
    respirationConfidence: number | null;
    source: string | null;
  };
  params: {
    colorHue: number;
    flowSpeed: number;
    distortion: number;
    particleDensity: number;
    brightness: number;
  };
  guidance: string;
}

/** Minimum confidence before we flag the detection as uncertain */
export const UNCERTAIN_THRESHOLD = 0.42;

export type BandHistory = {
  alpha: number;
  beta: number;
  theta: number;
  gamma: number;
  delta: number;
  t: number;
};

export type EmotionHistoryEntry = {
  emotion: string;
  confidence: number;
  t: number;
};

/** Max entries kept in the rolling emotion history */
const EMOTION_HISTORY_MAX = 20;

// Raw message shape sent by the backend (BrainStreamMessage)
interface BackendMessage {
  timestamp: number;
  alpha: number;
  beta: number;
  gamma: number;
  theta: number;
  delta: number;
  signal_quality: number;
  emotion: string;
  confidence: number;
  /** Raw single-frame detection before backend smoothing window */
  detected_emotion?: string;
  detected_confidence?: number;
  heart_bpm?: number | null;
  heart_confidence?: number | null;
  respiration_rpm?: number | null;
  respiration_confidence?: number | null;
  mindfulness?: number | null;
  restfulness?: number | null;
  pattern_type?: string;
  pattern_complexity?: number;
  color_palette?: string[];
  config?: {
    heart_signal_source?: string | null;
    [key: string]: unknown;
  };
  [key: string]: unknown;
}

// ---------------------------------------------------------------------------
// Convert a hex colour to its HSL hue (0–360)
// ---------------------------------------------------------------------------
function hexToHue(hex: string): number {
  const clean = hex.replace("#", "");
  if (clean.length !== 6) return 0;
  const r = parseInt(clean.slice(0, 2), 16) / 255;
  const g = parseInt(clean.slice(2, 4), 16) / 255;
  const b = parseInt(clean.slice(4, 6), 16) / 255;
  const max = Math.max(r, g, b),
    min = Math.min(r, g, b);
  if (max === min) return 0;
  const d = max - min;
  let h = 0;
  if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
  else if (max === g) h = ((b - r) / d + 2) / 6;
  else h = ((r - g) / d + 4) / 6;
  return Math.round(h * 360);
}

function clamp(v: number, lo = 0, hi = 1) {
  return Math.min(hi, Math.max(lo, v));
}

// ---------------------------------------------------------------------------
// Exponential moving average smoothing for visual params
// Prevents jittery visuals from noisy beta/gamma frames.
// ---------------------------------------------------------------------------
const EMA_ALPHA = 0.25; // lower = smoother, higher = more reactive
let _prevParams: SentioState["params"] | null = null;

function ema(next: number, prev: number): number {
  return parseFloat((EMA_ALPHA * next + (1 - EMA_ALPHA) * prev).toFixed(4));
}

// ---------------------------------------------------------------------------
// Compute live visual params from actual EEG band values each frame
//
//  colorHue        → hue of the first palette colour sent by the backend,
//                    falling back to the emotion-preset hue
//  flowSpeed       → beta power (higher beta = faster motion)
//  distortion      → pattern_complexity from the backend pattern mapper
//  particleDensity → alpha power weighted by signal confidence
//  brightness      → alpha raises it, theta lowers it
//
// All values are passed through an EMA to smooth out noisy frames.
// ---------------------------------------------------------------------------
function computeParams(msg: BackendMessage): SentioState["params"] {
  const emotionMeta = getEmotionMeta(msg.emotion);
  const alpha = clamp(msg.alpha ?? 0);
  const beta = clamp(msg.beta ?? 0);
  const theta = clamp(msg.theta ?? 0);
  const confidence = clamp(msg.confidence ?? 0);
  const complexity = clamp(msg.pattern_complexity ?? 0);

  // Colour hue: prefer backend palette, fallback to emotion preset
  const palette = msg.color_palette;
  const rawHue = palette?.length ? hexToHue(palette[0]) : emotionMeta.hue;

  const raw = {
    colorHue: rawHue,
    flowSpeed: clamp(beta * 0.75 + complexity * 0.25),
    distortion: clamp(complexity),
    particleDensity: clamp(alpha * 0.65 + confidence * 0.35),
    brightness: clamp(0.3 + alpha * 0.45 + (1 - theta) * 0.25),
  };

  if (!_prevParams) {
    _prevParams = raw;
    return raw;
  }

  // Hue needs circular interpolation to avoid jumping across 0/360
  const hueDiff = ((raw.colorHue - _prevParams.colorHue + 540) % 360) - 180;
  const smoothedHue = Math.round((_prevParams.colorHue + EMA_ALPHA * hueDiff + 360) % 360);

  const smoothed = {
    colorHue: smoothedHue,
    flowSpeed:       parseFloat(ema(raw.flowSpeed,       _prevParams.flowSpeed).toFixed(3)),
    distortion:      parseFloat(ema(raw.distortion,      _prevParams.distortion).toFixed(3)),
    particleDensity: parseFloat(ema(raw.particleDensity, _prevParams.particleDensity).toFixed(3)),
    brightness:      parseFloat(ema(raw.brightness,      _prevParams.brightness).toFixed(3)),
  };

  _prevParams = smoothed;
  return smoothed;
}

// ---------------------------------------------------------------------------
// Map raw backend frame → SentioState
// ---------------------------------------------------------------------------
function mapMessage(msg: BackendMessage): SentioState {
  const emotionMeta = getEmotionMeta(msg.emotion);
  const confidence = msg.confidence ?? 0;

  // detected_emotion is the raw single-frame label before backend smoothing.
  // Fall back to the main emotion when not present.
  const rawDetected = msg.detected_emotion ?? msg.emotion;
  const detectedMeta = getEmotionMeta(rawDetected);

  return {
    bands: {
      alpha: msg.alpha ?? 0,
      beta:  msg.beta  ?? 0,
      theta: msg.theta ?? 0,
      gamma: msg.gamma ?? 0,
      delta: msg.delta ?? 0,
    },
    emotion:            emotionMeta.key,
    confidence,
    detectedEmotion:    detectedMeta.key,
    detectedConfidence: msg.detected_confidence ?? confidence,
    isUncertain:        confidence < UNCERTAIN_THRESHOLD,
    mindfulness:        typeof msg.mindfulness === "number" ? msg.mindfulness : null,
    restfulness:        typeof msg.restfulness === "number" ? msg.restfulness  : null,
    signal_quality:     msg.signal_quality ?? 0,
    vitals: {
      heartBpm:
        typeof msg.heart_bpm === "number" ? msg.heart_bpm : null,
      heartConfidence:
        typeof msg.heart_confidence === "number" ? msg.heart_confidence : null,
      respirationRpm:
        typeof msg.respiration_rpm === "number" ? msg.respiration_rpm : null,
      respirationConfidence:
        typeof msg.respiration_confidence === "number"
          ? msg.respiration_confidence
          : null,
      source:
        msg.config && typeof msg.config.heart_signal_source === "string"
          ? msg.config.heart_signal_source
          : null,
    },
    params:   computeParams(msg),
    guidance: emotionMeta.guidance,
  };
}

// ---------------------------------------------------------------------------
// Default / loading state
// ---------------------------------------------------------------------------
const DEFAULT: SentioState = {
  bands: { alpha: 0, beta: 0, theta: 0, gamma: 0, delta: 0 },
  emotion: "neutral",
  confidence: 0,
  detectedEmotion: "neutral",
  detectedConfidence: 0,
  isUncertain: true,
  mindfulness: null,
  restfulness: null,
  signal_quality: 0,
  vitals: {
    heartBpm: null,
    heartConfidence: null,
    respirationRpm: null,
    respirationConfidence: null,
    source: null,
  },
  params: {
    colorHue: 120,
    flowSpeed: 0,
    distortion: 0,
    particleDensity: 0,
    brightness: 0.3,
  },
  guidance: "Connecting to Sentio backend…",
};

// ---------------------------------------------------------------------------
// Resolve WebSocket URL from saved API URL
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------
export function useWebSocket() {
  const [data, setData] = useState<SentioState>(DEFAULT);
  const [connected, setConnected] = useState(false);
  const [hasSignal, setHasSignal] = useState(false);
  const [history, setHistory] = useState<BandHistory[]>([]);
  const [emotionHistory, setEmotionHistory] = useState<EmotionHistoryEntry[]>([]);
  const wsRef = useRef<WebSocket | null>(null);

  useEffect(() => {
    let cancelled = false;

    function connect() {
      if (cancelled) return;

      const url = resolveBrainStreamUrl();
      const ws = new WebSocket(url);
      wsRef.current = ws;

      ws.onopen = () => {
        if (!cancelled) {
          setConnected(true);
          setHasSignal(false);
        }
      };

      ws.onmessage = (e) => {
        if (cancelled) return;
        try {
          const raw = JSON.parse(e.data);
          // Skip heartbeat / non-EEG control frames
          if (raw?.type === "heartbeat" || raw?.status === "waiting") return;
          const mapped = mapMessage(raw as BackendMessage);
          setData(mapped);
          setHasSignal(true);
          setHistory((previous) => [
            ...previous.slice(-99),
            { ...mapped.bands, t: Date.now() },
          ]);
          setEmotionHistory((previous) => {
            const last = previous[previous.length - 1];
            // Only append when emotion actually changes or every ~2 s
            if (last && last.emotion === mapped.emotion && Date.now() - last.t < 2000) {
              return previous;
            }
            return [
              ...previous.slice(-(EMOTION_HISTORY_MAX - 1)),
              { emotion: mapped.emotion, confidence: mapped.confidence, t: Date.now() },
            ];
          });
        } catch {
          // malformed frame — ignore
        }
      };

      ws.onclose = () => {
        if (cancelled) return;
        setConnected(false);
        setHasSignal(false);
        setHistory([]);
        setEmotionHistory([]);
        _prevParams = null; // reset EMA on disconnect
        setTimeout(connect, 2000);
      };

      ws.onerror = () => ws.close();
    }

    connect();
    return () => {
      cancelled = true;
      wsRef.current?.close();
    };
  }, []);

  return { data, connected, hasSignal, history, emotionHistory };
}
