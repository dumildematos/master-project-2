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
const brainStreamUrl = import.meta.env.VITE_BRAIN_STREAM_URL;

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

const fallbackWave = (amplitude: number, frequency: number, phase: number) =>
  Array.from({ length: MAX_POINTS }, (_, index) => Math.sin(index * frequency + phase) * amplitude);

const createFallbackBrainData = (previous: BrainData | null): BrainData => {
  const alpha = 0.6 + Math.random() * 0.3;
  const beta = 0.3 + Math.random() * 0.3;
  const gamma = 0.2 + Math.random() * 0.2;
  const delta = Math.random() * 0.1;
  const theta = Math.random() * 0.2;
  const eegPoint = buildEegPoint({ alpha, beta, gamma, delta, theta });

  return {
    alpha,
    beta,
    confidence: 60 + Math.random() * 30,
    gamma,
    delta,
    theta,
    patternSeed: previous?.patternSeed ?? Math.floor(Math.random() * 100000),
    signal_quality: 90 + Math.random() * 10,
    emotion: ["Calm", "Focused", "Excited", "Relaxed"][Math.floor(Math.random() * 4)],
    timestamp: Date.now(),
    eegData: appendPoint(previous?.eegData ?? [], eegPoint),
    alphaWave: appendPoint(previous?.alphaWave ?? [], alpha),
    betaWave: appendPoint(previous?.betaWave ?? [], beta),
    gammaWave: appendPoint(previous?.gammaWave ?? [], gamma),
    thetaWave: appendPoint(previous?.thetaWave ?? [], theta),
  };
};

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

  useEffect(() => {
    let ws: WebSocket | null = null;
    let interval: ReturnType<typeof setInterval> | null = null;

    const startFallback = () => {
      if (interval) {
        return;
      }

      interval = globalThis.setInterval(() => {
        setBrainData(createFallbackBrainData);
      }, 100);
    };

    if (!calibration) {
      return () => {
        if (interval) {
          globalThis.clearInterval(interval);
        }
      };
    }

    ws = new WebSocket(brainStreamUrl);
    ws.onmessage = (event) => {
      try {
        const payload = JSON.parse(event.data) as Record<string, unknown>;
        setBrainData((previous) => parseBrainStreamPayload(payload, previous));
      } catch (error) {
        console.error("Failed to parse brain stream payload", error);
      }
    };
    ws.onerror = startFallback;
    ws.onclose = startFallback;

    return () => {
      if (ws) {
        ws.close();
      }

      if (interval) {
        globalThis.clearInterval(interval);
      }
    };
  }, [calibration]);

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
