import {
  createContext,
  useContext,
  useState,
  useEffect,
  useMemo,
  type Dispatch,
  type ReactNode,
  type SetStateAction,
} from "react";
import { resolveBrainStreamUrl } from "../lib/runtimeConfig";

export interface CalibrationConfig {
  progress: number;
  signal_quality: number;
  noise_level: number;
  status_message: string;
}

export interface BrainData {
  alpha: number;
  beta: number;
  confidence: number;
  gamma: number;
  delta: number;
  theta: number;
  heartBpm: number | null;
  heartConfidence: number | null;
  respirationRpm: number | null;
  respirationConfidence: number | null;
  patternSeed: number | null;
  signal_quality: number;
  emotion: string;
  timestamp: number;
  eegData: number[];
  alphaWave: number[];
  betaWave: number[];
  gammaWave: number[];
  thetaWave: number[];
}

interface BrainContextType {
  calibration: CalibrationConfig | null;
  setCalibration: Dispatch<SetStateAction<CalibrationConfig | null>>;
  brainData: BrainData | null;
  setBrainData: Dispatch<SetStateAction<BrainData | null>>;
}

const BrainContext = createContext<BrainContextType | undefined>(undefined);

const MAX_POINTS = 120;
const WS_RETRY_DELAY_MS = 2000;

const takeRecentValues = (value: unknown): number[] => {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .filter((item): item is number => typeof item === "number")
    .slice(-MAX_POINTS);
};

const appendPoint = (series: number[], point: number) => [...series, point].slice(-MAX_POINTS);

const toPercent = (value: unknown, fallback = 0) => {
  const parsed = typeof value === "number" ? value : fallback;

  if (parsed >= 0 && parsed <= 1) {
    return parsed * 100;
  }

  return parsed;
};

const toEmotionLabel = (value: unknown) => {
  if (typeof value !== "string") {
    return "";
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return "";
  }

  return `${trimmed.charAt(0).toUpperCase()}${trimmed.slice(1).toLowerCase()}`;
};

const buildEegPoint = ({ alpha, beta, gamma, delta, theta }: Pick<BrainData, "alpha" | "beta" | "gamma" | "delta" | "theta">) =>
  alpha * 28 + beta * 34 + gamma * 42 + delta * 18 + theta * 22;


const parseNumber = (value: unknown, fallback = 0) => (typeof value === "number" ? value : fallback);

const parseBrainStreamPayload = (payload: Record<string, unknown>, previous: BrainData | null): BrainData => {
  const alpha = parseNumber(payload.alpha);
  const beta = parseNumber(payload.beta);
  const gamma = parseNumber(payload.gamma);
  const delta = parseNumber(payload.delta);
  const theta = parseNumber(payload.theta);
  const alphaWave = takeRecentValues(payload.alpha_wave);
  const betaWave = takeRecentValues(payload.beta_wave);
  const gammaWave = takeRecentValues(payload.gamma_wave);
  const thetaWave = takeRecentValues(payload.theta_wave);
  const eegData = takeRecentValues(payload.eeg);
  const eegPoint = buildEegPoint({ alpha, beta, gamma, delta, theta });

  return {
    alpha,
    beta,
    confidence: toPercent(payload.confidence),
    gamma,
    delta,
    theta,
    heartBpm: typeof payload.heart_bpm === "number" ? payload.heart_bpm : previous?.heartBpm ?? null,
    heartConfidence: typeof payload.heart_confidence === "number" ? payload.heart_confidence : previous?.heartConfidence ?? null,
    respirationRpm: typeof payload.respiration_rpm === "number" ? payload.respiration_rpm : previous?.respirationRpm ?? null,
    respirationConfidence: typeof payload.respiration_confidence === "number" ? payload.respiration_confidence : previous?.respirationConfidence ?? null,
    patternSeed: typeof payload.pattern_seed === "number" ? payload.pattern_seed : previous?.patternSeed ?? null,
    signal_quality: toPercent(payload.signal_quality, parseNumber(payload.signal)),
    emotion: toEmotionLabel(payload.emotion),
    timestamp: parseNumber(payload.timestamp, Date.now()),
    eegData: eegData.length ? eegData : appendPoint(previous?.eegData ?? [], eegPoint),
    alphaWave: alphaWave.length ? alphaWave : appendPoint(previous?.alphaWave ?? [], alpha),
    betaWave: betaWave.length ? betaWave : appendPoint(previous?.betaWave ?? [], beta),
    gammaWave: gammaWave.length ? gammaWave : appendPoint(previous?.gammaWave ?? [], gamma),
    thetaWave: thetaWave.length ? thetaWave : appendPoint(previous?.thetaWave ?? [], theta),
  };
};

export const useBrainContext = () => {
  const ctx = useContext(BrainContext);
  if (!ctx) throw new Error("BrainContext not found");
  return ctx;
};

export const BrainProvider = ({ children }: { children: ReactNode }) => {
  const [calibration, setCalibration] = useState<CalibrationConfig | null>(null);
  const [brainData, setBrainData] = useState<BrainData | null>(null);

  // Open the WebSocket on mount — calibration is display metadata, not a data gate.
  useEffect(() => {
    let ws: WebSocket | null = null;
    let retryTimeout: ReturnType<typeof setTimeout> | null = null;
    let cancelled = false;

    function connect() {
      if (cancelled) return;

      ws = new WebSocket(resolveBrainStreamUrl());

      ws.onmessage = (event) => {
        if (cancelled) return;
        try {
          const payload = JSON.parse(event.data) as Record<string, unknown>;
          // Skip heartbeat / non-EEG control frames
          if (payload?.type === "heartbeat" || payload?.status === "waiting") return;
          setBrainData((previous) => parseBrainStreamPayload(payload, previous));
        } catch (error) {
          console.error("Failed to parse brain stream payload", error);
        }
      };

      ws.onclose = () => {
        if (cancelled) return;
        // Keep last brainData — don't flash to null on brief disconnect.
        retryTimeout = setTimeout(connect, WS_RETRY_DELAY_MS);
      };

      ws.onerror = () => ws?.close();
    }

    connect();

    return () => {
      cancelled = true;
      if (retryTimeout) clearTimeout(retryTimeout);
      ws?.close();
    };
  }, []);

  const value = useMemo(
    () => ({ calibration, setCalibration, brainData, setBrainData }),
    [calibration, brainData],
  );

  return (
    <BrainContext.Provider value={value}>
      {children}
    </BrainContext.Provider>
  );
};
