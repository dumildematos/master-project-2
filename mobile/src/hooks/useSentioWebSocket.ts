/**
 * useSentioWebSocket
 * ------------------
 * React Native WebSocket hook — identical contract to the web frontend's
 * useWebSocket.ts so screens can be built with the same shape of data.
 *
 * Connects to ws://<host>:<port>/ws/brain-stream, auto-reconnects on close,
 * and exposes the latest SentioState plus band/emotion history.
 */

import { useEffect, useRef, useState, useCallback } from "react";
import { buildWsUrl } from "../lib/runtimeConfig";

// ---------------------------------------------------------------------------
// Types (mirrors web frontend)
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
  confidence:         number;
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
  aiGuidance:  string | null;
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

export type BandHistory = {
  alpha: number; beta: number; theta: number;
  gamma: number; delta: number; t: number;
};

export type EmotionHistoryEntry = { emotion: string; confidence: number; t: number };

const UNCERTAIN_THRESHOLD  = 0.42;
const EMOTION_HISTORY_MAX  = 20;

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
// Hook
// ---------------------------------------------------------------------------
export function useSentioWebSocket() {
  const [data,           setData          ] = useState<SentioState>(DEFAULT);
  const [connected,      setConnected     ] = useState(false);
  const [hasSignal,      setHasSignal     ] = useState(false);
  const [history,        setHistory       ] = useState<BandHistory[]>([]);
  const [emotionHistory, setEmotionHistory] = useState<EmotionHistoryEntry[]>([]);
  const [wsUrl,          setWsUrl         ] = useState<string | null>(null);

  const wsRef      = useRef<WebSocket | null>(null);
  const cancelRef  = useRef(false);
  const retryTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Re-run the effect whenever the URL changes (settings saved)
  const reconnect = useCallback(async () => {
    const url = await buildWsUrl();
    setWsUrl(url);
  }, []);

  useEffect(() => {
    reconnect();
  }, [reconnect]);

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
        setHasSignal(false);
      };

      ws.onmessage = (e) => {
        if (cancelRef.current) return;
        try {
          const raw = JSON.parse(e.data);
          if (raw?.type === "heartbeat" || raw?.status === "waiting") return;

          const confidence = raw.confidence ?? 0;
          const mapped: SentioState = {
            bands: {
              alpha: raw.alpha ?? 0,
              beta:  raw.beta  ?? 0,
              theta: raw.theta ?? 0,
              gamma: raw.gamma ?? 0,
              delta: raw.delta ?? 0,
            },
            emotion:            raw.emotion            ?? "neutral",
            confidence,
            detectedEmotion:    raw.detected_emotion   ?? raw.emotion ?? "neutral",
            detectedConfidence: raw.detected_confidence ?? confidence,
            isUncertain:        confidence < UNCERTAIN_THRESHOLD,
            mindfulness:        typeof raw.mindfulness  === "number" ? raw.mindfulness  : null,
            restfulness:        typeof raw.restfulness  === "number" ? raw.restfulness  : null,
            signal_quality:     raw.signal_quality      ?? 0,
            vitals: {
              heartBpm:              typeof raw.heart_bpm             === "number" ? raw.heart_bpm             : null,
              heartConfidence:       typeof raw.heart_confidence      === "number" ? raw.heart_confidence      : null,
              respirationRpm:        typeof raw.respiration_rpm       === "number" ? raw.respiration_rpm       : null,
              respirationConfidence: typeof raw.respiration_confidence === "number" ? raw.respiration_confidence : null,
              source: raw.config?.heart_signal_source ?? null,
            },
            aiGuidance: typeof raw.ai_guidance === "string" && raw.ai_guidance ? raw.ai_guidance : null,
            aiPattern:  raw.ai_pattern && raw.ai_pattern.pattern_type ? raw.ai_pattern : null,
          };

          setData(mapped);
          setHasSignal(true);
          setHistory((prev) => [...prev.slice(-99), { ...mapped.bands, t: Date.now() }]);
          setEmotionHistory((prev) => {
            const last = prev[prev.length - 1];
            if (last && last.emotion === mapped.emotion && Date.now() - last.t < 2000) return prev;
            return [...prev.slice(-(EMOTION_HISTORY_MAX - 1)), { emotion: mapped.emotion, confidence, t: Date.now() }];
          });
        } catch {
          // malformed frame — ignore
        }
      };

      ws.onclose = () => {
        if (cancelRef.current) return;
        setConnected(false);
        setHasSignal(false);
        setHistory([]);
        setEmotionHistory([]);
        retryTimer.current = setTimeout(connect, 2000);
      };

      ws.onerror = () => ws.close();
    }

    connect();

    return () => {
      cancelRef.current = true;
      if (retryTimer.current) clearTimeout(retryTimer.current);
      wsRef.current?.close();
    };
  }, [wsUrl]);

  return { data, connected, hasSignal, history, emotionHistory, reconnect };
}
