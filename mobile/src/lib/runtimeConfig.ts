/**
 * runtimeConfig.ts  (Ionic / Capacitor)
 * --------------------------------------
 * Stores settings in Capacitor Preferences (replaces React Native AsyncStorage).
 * Gracefully falls back to localStorage when running in web/browser context
 * (e.g. ionic serve / vite dev server).
 */
import { Preferences } from "@capacitor/preferences";

const KEY_URL = "sentioApiUrl";
const KEY_MAC = "muse2MacAddress";
const DEFAULT_URL = "http://127.0.0.1:8000";
const WS_PATH = "/ws/brain-stream";

function trimSlash(v: string): string {
  return v.replace(/\/+$/, "");
}

async function getItem(key: string): Promise<string | null> {
  const { value } = await Preferences.get({ key });
  return value;
}

async function setItem(key: string, value: string): Promise<void> {
  await Preferences.set({ key, value });
}

export async function getStoredApiUrl(): Promise<string> {
  const stored = await getItem(KEY_URL);
  return trimSlash(stored ?? DEFAULT_URL);
}

export async function saveApiUrl(url: string): Promise<void> {
  await setItem(KEY_URL, trimSlash(url.trim()));
}

export async function getStoredMac(): Promise<string> {
  return (await getItem(KEY_MAC)) ?? "";
}

export async function saveMac(mac: string): Promise<void> {
  await setItem(KEY_MAC, mac.trim());
}

export async function resolveApiBaseUrl(): Promise<string> {
  return getStoredApiUrl();
}

export async function resolveBrainStreamUrl(): Promise<string> {
  const base = await getStoredApiUrl();
  const wsBase = base
    .replace(/^https:/, "wss:")
    .replace(/^http:/,  "ws:");
  return `${trimSlash(wsBase)}${WS_PATH}`;
}
