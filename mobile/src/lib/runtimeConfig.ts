import AsyncStorage from "@react-native-async-storage/async-storage";

const DEFAULT_HOST = "10.208.193.106"; // LAN IP of the Sentio backend
const DEFAULT_PORT = 8000;
const WS_PATH      = "/ws/brain-stream";

const KEY_HOST = "sentio:host";
const KEY_PORT = "sentio:port";

export async function getStoredHost(): Promise<string> {
  return (await AsyncStorage.getItem(KEY_HOST)) ?? DEFAULT_HOST;
}

export async function getStoredPort(): Promise<number> {
  const raw = await AsyncStorage.getItem(KEY_PORT);
  const n   = raw ? parseInt(raw, 10) : NaN;
  return isNaN(n) ? DEFAULT_PORT : n;
}

export async function saveHost(host: string): Promise<void> {
  await AsyncStorage.setItem(KEY_HOST, host.trim());
}

export async function savePort(port: number): Promise<void> {
  await AsyncStorage.setItem(KEY_PORT, String(port));
}

export async function buildWsUrl(): Promise<string> {
  const host = await getStoredHost();
  const port = await getStoredPort();
  return `ws://${host}:${port}${WS_PATH}`;
}
