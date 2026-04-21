const DEFAULT_API_PORT = "8000";

function trimTrailingSlash(value: string): string {
  return value.replace(/\/+$/, "");
}

/**
 * Parse `value` into a URL object.
 *
 * Handles three forms:
 *   1. Absolute URL      "http://localhost:8000"   → parsed directly
 *   2. Origin-relative   "/_/backend"              → resolved against window.location.origin
 *   3. Bare host[:port]  "192.168.1.5:8000"        → prefixed with fallbackProtocol://
 */
function ensureAbsoluteUrl(
  value: string,
  fallbackProtocol: "http:" | "ws:",
): URL | null {
  // 1. Already absolute
  try {
    return new URL(value);
  } catch {
    // not absolute — continue
  }

  // 2. Root-relative path — resolve against the current origin
  if (typeof window !== "undefined" && value.startsWith("/")) {
    try {
      return new URL(value, window.location.origin);
    } catch {
      // fall through
    }
  }

  // 3. Bare host or host:port
  try {
    return new URL(`${fallbackProtocol}//${value}`);
  } catch {
    return null;
  }
}

function getDefaultApiBaseUrl(): string {
  if (typeof window !== "undefined") {
    const { protocol, hostname } = window.location;
    const apiProtocol = protocol === "https:" ? "https:" : "http:";
    return `${apiProtocol}//${hostname}:${DEFAULT_API_PORT}`;
  }

  return `http://localhost:${DEFAULT_API_PORT}`;
}

export function resolveApiBaseUrl(): string {
  const stored =
    typeof window !== "undefined"
      ? window.localStorage.getItem("sentioApiUrl")
      : null;
  const envValue = import.meta.env.VITE_API_BASE_URL;
  const candidate = trimTrailingSlash(
    stored || envValue || getDefaultApiBaseUrl(),
  );
  const resolved = ensureAbsoluteUrl(candidate, "http:");

  return resolved
    ? trimTrailingSlash(resolved.toString())
    : getDefaultApiBaseUrl();
}

export function resolveBrainStreamUrl(): string {
  const stored =
    typeof window !== "undefined"
      ? window.localStorage.getItem("sentioApiUrl")
      : null;
  const envValue = import.meta.env.VITE_BRAIN_STREAM_URL;

  if (envValue) {
    const wsUrl = ensureAbsoluteUrl(trimTrailingSlash(envValue), "ws:");
    if (wsUrl) {
      if (!wsUrl.pathname || wsUrl.pathname === "/") {
        wsUrl.pathname = "/ws/brain-stream";
      }
      return wsUrl.toString();
    }
  }

  const apiUrl = ensureAbsoluteUrl(
    trimTrailingSlash(stored || resolveApiBaseUrl()),
    "http:",
  );
  if (!apiUrl) {
    return `ws://localhost:${DEFAULT_API_PORT}/ws/brain-stream`;
  }

  apiUrl.protocol = apiUrl.protocol === "https:" ? "wss:" : "ws:";
  // Append /ws/brain-stream to whatever path the API base already has
  // e.g. "/_/backend" → "wss://app.vercel.app/_/backend/ws/brain-stream"
  apiUrl.pathname = `${trimTrailingSlash(apiUrl.pathname)}/ws/brain-stream`;
  apiUrl.search = "";
  apiUrl.hash = "";
  return apiUrl.toString();
}
