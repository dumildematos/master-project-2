/**
 * sentioApi.ts  (mobile)
 * ----------------------
 * REST API wrappers — identical to what the web frontend calls.
 * Router prefix in main.py is /api, so all paths are /api/<endpoint>.
 * EMOTION_PRESETS match frontend/src/hooks/useManualMode.ts exactly.
 */
import { resolveApiBaseUrl } from "./runtimeConfig";

async function api(path: string, init?: RequestInit): Promise<Response> {
  const base = await resolveApiBaseUrl();
  return fetch(`${base}/api${path}`, {
    headers: { "Content-Type": "application/json" },
    ...init,
  });
}

// ---------------------------------------------------------------------------
// Session
// ---------------------------------------------------------------------------
export interface SessionStatus {
  session_id:             string | null;
  state:                  "idle" | "connecting" | "running" | "stopping" | string;
  start_time:             number | null;
  emotion_history_length: number;
}

export async function getSessionStatus(): Promise<SessionStatus> {
  const res = await api("/session/status");
  if (!res.ok) throw new Error(`Session status ${res.status}`);
  return res.json();
}

export type DeviceSource = "auto" | "brainflow" | "bluemuse" | "mobile";

export interface SessionConfig {
  pattern_type:       string;
  signal_sensitivity: number;        // 0–1
  emotion_smoothing:  number;        // 0–1
  noise_control?:     number;
  device_source?:     DeviceSource;  // "mobile" → backend skips BLE
  mac_address?:       string;
  age?:               number;
  gender?:            string;
}

export async function startSession(config: SessionConfig): Promise<{ session_id: string; status: string }> {
  const res = await api("/session/start", {
    method: "POST",
    body:   JSON.stringify(config),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    const detail = err?.detail;
    if (Array.isArray(detail)) {
      throw new Error(detail.map((d: any) => `${(d.loc ?? []).join(".")}: ${d.msg}`).join("\n"));
    }
    throw new Error(typeof detail === "string" ? detail : `Start failed (${res.status})`);
  }
  return res.json();
}

export async function stopSession(): Promise<void> {
  const res = await api("/session/stop", { method: "POST" });
  if (!res.ok) throw new Error(`Stop session ${res.status}`);
}

// ---------------------------------------------------------------------------
// Manual override — same presets as frontend/src/hooks/useManualMode.ts
// ---------------------------------------------------------------------------
export type EmotionKey = "calm" | "focused" | "stressed" | "relaxed" | "excited";

export const EMOTION_PRESETS: Record<EmotionKey, {
  alpha: number; beta: number; theta: number;
  gamma: number; delta: number; confidence: number;
}> = {
  calm:     { alpha: 0.68, beta: 0.18, theta: 0.16, gamma: 0.06, delta: 0.05, confidence: 0.84 },
  focused:  { alpha: 0.32, beta: 0.72, theta: 0.10, gamma: 0.14, delta: 0.03, confidence: 0.91 },
  stressed: { alpha: 0.22, beta: 0.88, theta: 0.08, gamma: 0.18, delta: 0.04, confidence: 0.76 },
  relaxed:  { alpha: 0.75, beta: 0.12, theta: 0.45, gamma: 0.05, delta: 0.08, confidence: 0.88 },
  excited:  { alpha: 0.40, beta: 0.65, theta: 0.12, gamma: 0.32, delta: 0.04, confidence: 0.87 },
};

export async function sendManualOverride(emotion: EmotionKey): Promise<void> {
  const bands = EMOTION_PRESETS[emotion];
  const res   = await api("/manual/override", {
    method: "POST",
    body:   JSON.stringify({ emotion, ...bands }),
  });
  if (!res.ok) throw new Error(`Override ${res.status}`);
}
