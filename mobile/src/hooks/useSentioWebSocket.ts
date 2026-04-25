/**
 * useSentioWebSocket  (mobile)
 * ----------------------------
 * Mirrors the logic of frontend/src/hooks/useWebSocket.ts and
 * frontend/src/context/BrainContext.tsx.
 *
 * - Connects to ws://<host>/ws/brain-stream derived from stored sentioApiUrl
 * - Filters heartbeat / waiting control frames
 * - Auto-reconnects on close with 2 s backoff
 * - Keeps last data on brief disconnect (does NOT reset to null)
 * - Re-connects when `wsUrl` changes (after saving new backend address)
 */
import { useEffect, useRef, useState, useCallback } from "react";
import { resolveBrainStreamUrl } from "../lib/runtimeConfig";

// ---------------------------------------------------------------------------
// Types — identical field names to the web frontend's SentioState
// ---------------------------------------------------------------------------
export interface SentioState {
  bands: {
    alpha: number;
    beta:  number;
    theta: number;
    gamma: number;
    delta: number;
  };
  emotion:            string;
  confidence:         number;       // 0–100 (% — matches BrainContext)
  detectedEmotion:    string;
  detectedConfidence: number;
  isUncertain:        boolean;
  mindfulness:        number | null;
  restfulness:        number | null;
  signal_quality:     number;
  vitals: {
    heartBpm:              number | null;
    heartConfidence:       number | null;
    respirationRpm:        number | null;
    respirationConfidence: number | null;
    source:                string | null;
  };
  aiGuidance: string | null;
  aiPattern: {
    pattern_type: string;
    primary:      string;
    secondary:    string;
    accent:       string;
    shadow:       string;
    speed:        number;
    complexity:   number;
    intensity:    number;
  } | null;
}

export type BandHistory      = { alpha: number; beta: number; theta: number; gamma: number; delta: number; t: number };
export type EmotionHistoryEntry = { emotion: string; confidence: number; t: number };

const UNCERTAIN_THRESHOLD = 42;   // percent — mirrors BrainContext
const EMOTION_HISTORY_MAX = 20;
const WS_RETRY_DELAY_MS   = 2000;

const DEFAULT: SentioState = {
  bands:              { alpha: 0, beta: 0, theta: 0, gamma: 0, delta: 0 },
  emotion:            "neutral",
  confidence:         0,
  detectedEmotion:    "neutral",
  detectedConfidence: 0,
  isUncertain:        true,
  mindfulness:        null,
  restfulness:        null,
  signal_quality:     0,
  vitals:             { heartBpm: null, heartConfidence: null, respirationRpm: null, respirationConfidence: null, source: null },
  aiGuidance:         null,
  aiPattern:          null,
};

// ---------------------------------------------------------------------------
// Frame parser — mirrors parseBrainStreamPayload in BrainContext.tsx
// ---------------------------------------------------------------------------
function parseFrame(raw: Record<string, unknown>, prev: SentioState): SentioState {
  const toNum = (v: unknown, fb = 0) => (typeof v === "number" ? v : fb);

  const rawConf    = toNum(raw.confidence);
  const confidence = rawConf <= 1 ? rawConf * 100 : rawConf;   // normalise to %

  const toLabel = (v: unknown) => {
    if (typeof v !== "string" || !v.trim()) return "neutral";
    const t = v.trim();
    return `${t.charAt(0).toUpperCase()}${t.slice(1).toLowerCase()}`;
  };

  return {
    bands: {
      alpha: toNum(raw.alpha),
      beta:  toNum(raw.beta),
      theta: toNum(raw.theta),
      gamma: toNum(raw.gamma),
      delta: toNum(raw.delta),
    },
    emotion:         toLabel(raw.emotion),
    confidence,
    detectedEmotion: toLabel(raw.detected_emotion ?? raw.emotion),
    detectedConfidence:
      typeof raw.detected_confidence === "number"
        ? (raw.detected_confidence <= 1 ? raw.detected_confidence * 100 : raw.detected_confidence)
        : confidence,
    isUncertain: confidence < UNCERTAIN_THRESHOLD,
    mindfulness:  typeof raw.mindfulness  === "number" ? raw.mindfulness  : null,
    restfulness:  typeof raw.restfulness  === "number" ? raw.restfulness  : null,
    signal_quality:
      typeof raw.signal_quality === "number"
        ? raw.signal_quality
        : (typeof raw.signal === "number" ? raw.signal * 100 : prev.signal_quality),
    vitals: {
      heartBpm:              typeof raw.heart_bpm              === "number" ? raw.heart_bpm              : prev.vitals.heartBpm,
      heartConfidence:       typeof raw.heart_confidence       === "number" ? raw.heart_confidence       : prev.vitals.heartConfidence,
      respirationRpm:        typeof raw.respiration_rpm        === "number" ? raw.respiration_rpm        : prev.vitals.respirationRpm,
      respirationConfidence: typeof raw.respiration_confidence === "number" ? raw.respiration_confidence : prev.vitals.respirationConfidence,
      source: (raw.config as any)?.heart_signal_source ?? prev.vitals.source,
    },
    aiGuidance: typeof raw.ai_guidance === "string" && raw.ai_guidance ? raw.ai_guidance : null,
    aiPattern:  raw.ai_pattern && (raw.ai_pattern as any).pattern_type ? raw.ai_pattern as SentioState["aiPattern"] : null,
  };
}

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------
export function useSentioWebSocket() {
  const [data,           setData          ] = useState<SentioState>(DEFAULT);
  const [connected,      setConnected     ] = useState(false);
  const [hasSignal,      setHasSignal     ] = useState(false);
  const [history,        setHistory       ] = useState<BandHistory[]>([]);
  const [emotionHistory, setEmotionHistory] = useState<EmotionHistoryEntry[]>([]);
  const [wsUrl,          setWsUrl         ] = useState<string | null>(null);

  const cancelRef  = useRef(false);
  const wsRef      = useRef<WebSocket | null>(null);
  const retryRef   = useRef<ReturnType<typeof setTimeout> | null>(null);
  const dataRef    = useRef<SentioState>(DEFAULT);   // for parseFrame prev

  /** Call to reload the stored URL and reconnect (e.g. after saving settings). */
  const reconnect = useCallback(async () => {
    const url = await resolveBrainStreamUrl();
    setWsUrl(url);
  }, []);

  // Initial load
  useEffect(() => { reconnect(); }, [reconnect]);

  useEffect(() => {
    if (!wsUrl) return;
    cancelRef.current = false;

    function connect() {
      if (cancelRef.current) return;

      const ws = new WebSocket(wsUrl!);
      wsRef.current = ws;

      ws.onopen = () => {
        if (cancelRef.current) return;
        setConnected(true);
      };

      ws.onmessage = (e) => {
        if (cancelRef.current) return;
        try {
          const raw = JSON.parse(e.data) as Record<string, unknown>;
          // Skip heartbeat / waiting control frames (mirrors BrainContext)
          if (raw?.type === "heartbeat" || raw?.status === "waiting") return;

          const mapped = parseFrame(raw, dataRef.current);
          dataRef.current = mapped;
          setData(mapped);
          setHasSignal(true);
          setHistory(prev => [...prev.slice(-99), { ...mapped.bands, t: Date.now() }]);
          setEmotionHistory(prev => {
            const last = prev[prev.length - 1];
            if (last && last.emotion === mapped.emotion && Date.now() - last.t < 2000) return prev;
            return [...prev.slice(-(EMOTION_HISTORY_MAX - 1)), { emotion: mapped.emotion, confidence: mapped.confidence, t: Date.now() }];
          });
        } catch {
          // malformed frame — ignore
        }
      };

      ws.onclose = () => {
        if (cancelRef.current) return;
        setConnected(false);
        // Do NOT reset data — keep last values visible (mirrors BrainContext)
        retryRef.current = setTimeout(connect, WS_RETRY_DELAY_MS);
      };

      ws.onerror = () => ws.close();
    }

    connect();

    return () => {
      cancelRef.current = true;
      if (retryRef.current) clearTimeout(retryRef.current);
      wsRef.current?.close();
    };
  }, [wsUrl]);

  return { data, connected, hasSignal, history, emotionHistory, reconnect };
}
