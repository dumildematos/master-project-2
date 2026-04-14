import { useEffect, useRef, useState } from "react";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------
export interface SentioState {
  bands:      { alpha: number; beta: number; theta: number; gamma: number; delta: number };
  emotion:    string;
  confidence: number;
  signal_quality: number;
  params:     {
    colorHue:        number;
    flowSpeed:       number;
    distortion:      number;
    particleDensity: number;
    brightness:      number;
  };
  guidance: string;
}

export type BandHistory = {
  alpha: number; beta: number; theta: number; gamma: number; delta: number; t: number;
};

// Raw message shape sent by the backend (BrainStreamMessage)
interface BackendMessage {
  timestamp:          number;
  alpha:              number;
  beta:               number;
  gamma:              number;
  theta:              number;
  delta:              number;
  signal_quality:     number;
  emotion:            string;
  confidence:         number;
  mindfulness?:       number;
  restfulness?:       number;
  pattern_type?:      string;
  pattern_complexity?:number;
  color_palette?:     string[];
  [key: string]:      unknown;
}

// ---------------------------------------------------------------------------
// Emotion → base hue (colour identity per state)
// ---------------------------------------------------------------------------
const EMOTION_HUE: Record<string, number> = {
  calm:    210,
  focused: 40,
  stressed:0,
  relaxed: 180,
  excited: 30,
  neutral: 120,
};

const GUIDANCE: Record<string, string> = {
  calm:     "You're calm. Maintain this state to deepen the flowing visuals.",
  focused:  "High focus detected. The garment sharpens and becomes structured.",
  stressed: "Try to relax — take a slow breath to soften the visuals.",
  relaxed:  "Gentle state detected. Soft, slow forms are emerging.",
  excited:  "Excitement detected. Dynamic, vibrant patterns are forming.",
  neutral:  "Keep exploring your mental state to influence the design.",
};

// ---------------------------------------------------------------------------
// Convert a hex colour to its HSL hue (0–360)
// ---------------------------------------------------------------------------
function hexToHue(hex: string): number {
  const clean = hex.replace("#", "");
  if (clean.length !== 6) return 0;
  const r = parseInt(clean.slice(0, 2), 16) / 255;
  const g = parseInt(clean.slice(2, 4), 16) / 255;
  const b = parseInt(clean.slice(4, 6), 16) / 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  if (max === min) return 0;
  const d = max - min;
  let h = 0;
  if      (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
  else if (max === g) h = ((b - r) / d + 2) / 6;
  else                h = ((r - g) / d + 4) / 6;
  return Math.round(h * 360);
}

function clamp(v: number, lo = 0, hi = 1) { return Math.min(hi, Math.max(lo, v)); }

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
  const emotion    = msg.emotion ?? "neutral";
  const alpha      = clamp(msg.alpha      ?? 0);
  const beta       = clamp(msg.beta       ?? 0);
  const theta      = clamp(msg.theta      ?? 0);
  const confidence = clamp(msg.confidence ?? 0);
  const complexity = clamp(msg.pattern_complexity ?? 0);

  // Colour hue: prefer backend palette, fallback to emotion preset
  const palette  = msg.color_palette;
  const colorHue = palette?.length
    ? hexToHue(palette[0])
    : (EMOTION_HUE[emotion] ?? 120);

  return {
    colorHue,
    flowSpeed:       parseFloat(clamp(beta  * 0.75 + complexity * 0.25).toFixed(3)),
    distortion:      parseFloat(clamp(complexity).toFixed(3)),
    particleDensity: parseFloat(clamp(alpha * 0.65 + confidence * 0.35).toFixed(3)),
    brightness:      parseFloat(clamp(0.30  + alpha * 0.45 + (1 - theta) * 0.25).toFixed(3)),
  };
}

// ---------------------------------------------------------------------------
// Map raw backend frame → SentioState
// ---------------------------------------------------------------------------
function mapMessage(msg: BackendMessage): SentioState {
  const emotion = msg.emotion ?? "neutral";
  return {
    bands: {
      alpha: msg.alpha ?? 0,
      beta:  msg.beta  ?? 0,
      theta: msg.theta ?? 0,
      gamma: msg.gamma ?? 0,
      delta: msg.delta ?? 0,
    },
    emotion,
    confidence:     msg.confidence     ?? 0,
    signal_quality: msg.signal_quality ?? 0,
    params:         computeParams(msg),
    guidance:       GUIDANCE[emotion]  ?? GUIDANCE["neutral"],
  };
}

// ---------------------------------------------------------------------------
// Default / loading state
// ---------------------------------------------------------------------------
const DEFAULT: SentioState = {
  bands:         { alpha: 0, beta: 0, theta: 0, gamma: 0, delta: 0 },
  emotion:       "neutral",
  confidence:    0,
  signal_quality:0,
  params: {
    colorHue: 120, flowSpeed: 0, distortion: 0, particleDensity: 0, brightness: 0.30,
  },
  guidance:      "Connecting to Sentio backend…",
};

// ---------------------------------------------------------------------------
// Resolve WebSocket URL from saved API URL
// ---------------------------------------------------------------------------
function getWsUrl(): string {
  const stored = localStorage.getItem("sentioApiUrl") ?? "http://localhost:8000";
  // http://host:port  →  ws://host:port/ws/brain-stream
  return stored.replace(/^http/, "ws") + "/ws/brain-stream";
}

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------
export function useWebSocket() {
  const [data, setData]           = useState<SentioState>(DEFAULT);
  const [connected, setConnected] = useState(false);
  const [hasSignal, setHasSignal] = useState(false);
  const historyRef                = useRef<BandHistory[]>([]);
  const wsRef                     = useRef<WebSocket | null>(null);

  useEffect(() => {
    let cancelled = false;

    function connect() {
      if (cancelled) return;

      const url = getWsUrl();
      const ws  = new WebSocket(url);
      wsRef.current = ws;

      ws.onopen = () => {
        if (!cancelled) setConnected(true);
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
          historyRef.current = [
            ...historyRef.current.slice(-99),
            { ...mapped.bands, t: Date.now() },
          ];
        } catch {
          // malformed frame — ignore
        }
      };

      ws.onclose = () => {
        if (cancelled) return;
        setConnected(false);
        setHasSignal(false);
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

  return { data, connected, hasSignal, historyRef };
}
