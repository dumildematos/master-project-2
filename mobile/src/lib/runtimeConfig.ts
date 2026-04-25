/**
 * runtimeConfig.ts  (mobile)
 * --------------------------
 * Mirrors frontend/src/lib/runtimeConfig.ts.
 * Stores "sentioApiUrl" (full URL) and "muse2MacAddress" in AsyncStorage —
 * same keys the web frontend uses in localStorage.
 */
import AsyncStorage from "@react-native-async-storage/async-storage";

const STORAGE_KEY    = "sentioApiUrl";
const KEY_MAC        = "muse2MacAddress";
const DEFAULT_URL    = "http://127.0.0.1:8000";
const WS_PATH        = "/ws/brain-stream";

function trimTrailingSlash(value: string): string {
  return value.replace(/\/+$/, "");
}

/** Read the stored API base URL (or fall back to default). */
export async function getStoredApiUrl(): Promise<string> {
  const stored = await AsyncStorage.getItem(STORAGE_KEY);
  return trimTrailingSlash(stored ?? DEFAULT_URL);
}

/** Persist a new API base URL. */
export async function saveApiUrl(url: string): Promise<void> {
  await AsyncStorage.setItem(STORAGE_KEY, trimTrailingSlash(url.trim()));
}

// ---------------------------------------------------------------------------
// MAC address (Muse 2 device) — same localStorage key as web frontend
// ---------------------------------------------------------------------------
export async function getStoredMac(): Promise<string> {
  return (await AsyncStorage.getItem(KEY_MAC)) ?? "";
}
export async function saveMac(mac: string): Promise<void> {
  await AsyncStorage.setItem(KEY_MAC, mac.trim());
}

/**
 * HTTP base URL for REST calls — e.g. "http://192.168.1.5:8000"
 * All API endpoints are at `${resolveApiBaseUrl()}/api/<path>`.
 */
export async function resolveApiBaseUrl(): Promise<string> {
  return getStoredApiUrl();
}

/**
 * WebSocket URL — replaces http(s) with ws(s) and appends /ws/brain-stream.
 * e.g. "http://192.168.1.5:8000" → "ws://192.168.1.5:8000/ws/brain-stream"
 */
export async function resolveBrainStreamUrl(): Promise<string> {
  const base = await getStoredApiUrl();
  const wsBase = base
    .replace(/^https:/, "wss:")
    .replace(/^http:/, "ws:");
  return `${trimTrailingSlash(wsBase)}${WS_PATH}`;
}
