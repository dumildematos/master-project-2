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

export type BandHistory = {
  alpha: number;
  beta: number;
  theta: number;
  gamma: number;
  delta: number;
  t: number;
};

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
  heart_bpm?: number | null;
  heart_confidence?: number | null;
  respiration_rpm?: number | null;
  respiration_confidence?: number | null;
  mindfulness?: number;
  restfulness?: number;
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
// Compute live visual params from actual EEG band values each frame
//
//  colorHue        → hue of the first palette colour sent by the backend,
//                    falling back to the emotion-preset hue
//  flowSpeed       → beta power (higher beta = faster motion)
//  distortion      → pattern_complexity from the backend pattern mapper
//  particleDensity → alpha power weighted by signal confidence
//  brightness      → alpha raises it, theta lowers it
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
  const colorHue = palette?.length ? hexToHue(palette[0]) : emotionMeta.hue;

  return {
    colorHue,
    flowSpeed: parseFloat(clamp(beta * 0.75 + complexity * 0.25).toFixed(3)),
    distortion: parseFloat(clamp(complexity).toFixed(3)),
    particleDensity: parseFloat(
      clamp(alpha * 0.65 + confidence * 0.35).toFixed(3),
    ),
    brightness: parseFloat(
      clamp(0.3 + alpha * 0.45 + (1 - theta) * 0.25).toFixed(3),
    ),
  };
}

// ---------------------------------------------------------------------------
// Map raw backend frame → SentioState
// ---------------------------------------------------------------------------
function mapMessage(msg: BackendMessage): SentioState {
  const emotionMeta = getEmotionMeta(msg.emotion);
  return {
    bands: {
      alpha: msg.alpha ?? 0,
      beta: msg.beta ?? 0,
      theta: msg.theta ?? 0,
      gamma: msg.gamma ?? 0,
      delta: msg.delta ?? 0,
    },
    emotion: emotionMeta.key,
    confidence: msg.confidence ?? 0,
    signal_quality: msg.signal_quality ?? 0,
    vitals: {
      heartBpm: typeof msg.heart_bpm === "number" ? msg.heart_bpm : null,
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
    params: computeParams(msg),
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
        } catch {
          // malformed frame — ignore
        }
      };

      ws.onclose = () => {
        if (cancelled) return;
        setConnected(false);
        setHasSignal(false);
        setHistory([]);
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

  return { data, connected, hasSignal, history };
}
