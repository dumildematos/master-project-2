import { motion } from "framer-motion";
import { useEffect, useState } from "react";
import { useBrainContext } from "../../context/BrainContext";
import { Brain } from "lucide-react";
import { resolveApiBaseUrl } from "../../lib/runtimeConfig";

const steps = [
  { label: "Connecting to device", duration: 2000 },
  { label: "Reading brain signals", duration: 2500 },
  { label: "Calibrating sensors", duration: 3000 },
];

interface Props {
  onComplete: () => void;
}


const CalibrationScreen = ({ onComplete }: Props) => {
  const apiBaseUrl = resolveApiBaseUrl();
  const [stepIndex, setStepIndex] = useState(0);
  const [preProgress, setPreProgress] = useState(0); // progress before API call
  const [calibrationData, setCalibrationData] = useState<null | {
    progress: number;
    signal_quality: number;
    noise_level: number;
    status_message: string;
  }>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [apiStarted, setApiStarted] = useState(false);
  const { setCalibration } = useBrainContext();

  useEffect(() => {
    if (!apiStarted) {
      // Animate progress from 0 to 70
      let progress = 0;
      const interval = setInterval(() => {
        progress += 1;
        setPreProgress(progress);
        if (progress >= 70) {
          clearInterval(interval);
          setApiStarted(true);
        }
      }, 20); // 20ms per step, ~1.4s total
      return () => clearInterval(interval);
    }
  }, [apiStarted]);

  useEffect(() => {
    if (apiStarted) {
      const runCalibration = async () => {
        setLoading(true);
        setError(null);
        try {
          const response = await fetch(`${apiBaseUrl}/api/calibration/run`);
          if (!response.ok) {
            throw new Error("Calibration failed: " + response.status);
          }
          const data = await response.json();
          setCalibrationData(data);
          setCalibration(data);
          setLoading(false);
          setTimeout(onComplete, 500);
        } catch (err: unknown) {
          setError((err as Error)?.message || "Unknown error");
          setLoading(false);
        }
      };
      runCalibration();
    }
  }, [apiStarted, onComplete]);

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.5 }}
      className="min-h-screen flex flex-col items-center justify-center px-4"
    >
      {/* Brainwave background animation */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <BrainwaveLines />
      </div>

      {/* Muse 2 illustration */}
      <motion.div
        initial={{ scale: 0.8, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{ delay: 0.2, duration: 0.8 }}
        className="relative mb-12"
      >
        <div className="relative w-48 h-48 flex items-center justify-center">
          {/* Rotating ring */}
          <motion.div
            animate={{ rotate: 360 }}
            transition={{ duration: 8, repeat: Infinity, ease: "linear" }}
            className="absolute inset-0 rounded-full border border-primary/20"
            style={{
              borderImage: "linear-gradient(135deg, hsl(187 80% 55% / 0.4), transparent, hsl(270 60% 55% / 0.4), transparent) 1",
            }}
          />
          {/* Pulsing ring */}
          <motion.div
            animate={{ scale: [1, 1.15, 1], opacity: [0.3, 0.6, 0.3] }}
            transition={{ duration: 2, repeat: Infinity }}
            className="absolute inset-4 rounded-full border border-primary/30"
          />
          {/* Core */}
          <div className="glass-card w-24 h-24 rounded-full flex items-center justify-center">
            <Brain className="w-10 h-10 text-primary animate-glow-pulse" />
          </div>
        </div>
        {/* Headband illustration */}
        <svg viewBox="0 0 200 80" className="absolute -top-2 left-1/2 -translate-x-1/2 w-52">
          <path
            d="M30,60 Q100,0 170,60"
            fill="none"
            stroke="hsl(187 80% 55% / 0.3)"
            strokeWidth="3"
            strokeLinecap="round"
          />
          <circle cx="30" cy="60" r="4" fill="hsl(187 80% 55% / 0.6)" />
          <circle cx="170" cy="60" r="4" fill="hsl(187 80% 55% / 0.6)" />
          <circle cx="70" cy="22" r="3" fill="hsl(270 60% 55% / 0.6)" />
          <circle cx="100" cy="12" r="3" fill="hsl(270 60% 55% / 0.6)" />
          <circle cx="130" cy="22" r="3" fill="hsl(270 60% 55% / 0.6)" />
        </svg>
      </motion.div>

      {/* Status and API result */}
      <motion.div
        initial={{ y: 20, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.4 }}
        className="text-center space-y-6 z-10"
      >
        {loading && (
          <div>
            <p className="text-sm font-mono text-muted-foreground mb-1">Muse 2 Headband</p>
            <motion.p
              key={stepIndex}
              initial={{ opacity: 0, y: 5 }}
              animate={{ opacity: 1, y: 0 }}
              className="text-lg font-semibold glow-text-cyan"
            >
              Calibrating...
            </motion.p>
            <div className="w-72 mx-auto">
              <div className="h-1.5 bg-muted rounded-full overflow-hidden">
                <motion.div
                  className="h-full rounded-full"
                  style={{
                    width: `${apiStarted ? (calibrationData?.progress ?? 70) : preProgress}%`,
                    background: "linear-gradient(90deg, hsl(187 80% 55%), hsl(270 60% 55%))",
                  }}
                />
              </div>
              <p className="text-xs font-mono text-muted-foreground mt-2">{apiStarted ? Math.round(calibrationData?.progress ?? 70) : Math.round(preProgress)}%</p>
            </div>
          </div>
        )}
        {error && (
          <div className="text-red-500 font-mono">
            Error: {error}
          </div>
        )}
        {calibrationData && !loading && !error && (
          <div className="space-y-2">
            <div className="font-mono text-muted-foreground">Calibration Complete</div>
            <div className="font-mono">Progress: {calibrationData.progress}%</div>
            <div className="font-mono">Signal Quality: {calibrationData.signal_quality}</div>
            <div className="font-mono">Noise Level: {calibrationData.noise_level}</div>
            <div className="font-mono">Status: {calibrationData.status_message}</div>
          </div>
        )}
      </motion.div>
    </motion.div>
  );
};

const BrainwaveLines = () => (
  <svg className="w-full h-full opacity-10 animate-brainwave" viewBox="0 0 1200 600" preserveAspectRatio="none">
    {[150, 250, 350, 450].map((y, i) => (
      <path
        key={i}
        d={`M0,${y} ${Array.from({ length: 60 }, (_, j) => {
          const x = j * 40;
          const amp = 15 + i * 5;
          const freq = 0.15 + i * 0.05;
          return `L${x},${y + Math.sin(j * freq) * amp}`;
        }).join(" ")}`}
        fill="none"
        stroke={i % 2 === 0 ? "hsl(187 80% 55%)" : "hsl(270 60% 55%)"}
        strokeWidth="1.5"
      />
    ))}
  </svg>
);

export default CalibrationScreen;
