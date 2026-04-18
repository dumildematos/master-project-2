import React, { useEffect, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Brain, CheckCircle2 } from "lucide-react";

const STEPS = [
  { label: "Connecting to Muse 2",   detail: "Searching for device via Bluetooth…",  end: 28  },
  { label: "Reading brain signals",  detail: "Sampling EEG across 4 electrodes…",     end: 62  },
  { label: "Calibrating sensors",    detail: "Mapping baseline noise floor…",          end: 88  },
  { label: "Finalising calibration", detail: "Ready to generate your garment.",        end: 100 },
];

interface Props {
  onComplete: () => void;
}

export default function CalibrationScreen({ onComplete }: Props) {
  const [progress, setProgress]   = useState(0);
  const [stepIndex, setStepIndex] = useState(0);
  const [done, setDone]           = useState(false);

  /* Smooth progress ticker */
  useEffect(() => {
    if (done) return;
    const id = setInterval(() => {
      setProgress((prev) => {
        const next = prev + 0.55;

        // Advance visible step
        const newStep = STEPS.findIndex((s) => next < s.end);
        setStepIndex(newStep === -1 ? STEPS.length - 1 : newStep);

        if (next >= 100) {
          clearInterval(id);
          setDone(true);
          setTimeout(onComplete, 1200);
          return 100;
        }
        return next;
      });
    }, 30);
    return () => clearInterval(id);
  }, [done, onComplete]);

  const currentStep = STEPS[stepIndex];

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0, y: -20 }}
      transition={{ duration: 0.5 }}
      className="min-h-screen flex flex-col items-center justify-center px-4 relative overflow-hidden"
    >
      {/* Scrolling brainwave backdrop */}
      <div className="absolute inset-0 pointer-events-none overflow-hidden opacity-[0.07]">
        <BrainwaveLines />
      </div>

      {/* Logo */}
      <motion.div
        initial={{ y: -20, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.1 }}
        className="flex items-center gap-3 mb-14"
      >
        <Brain className="w-7 h-7 text-primary" />
        <span className="text-3xl font-bold tracking-tight glow-text-cyan">Sentio</span>
      </motion.div>

      {/* Device illustration */}
      <motion.div
        initial={{ scale: 0.85, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{ delay: 0.25, duration: 0.7, ease: "easeOut" }}
        className="relative mb-14"
        style={{ width: 260, height: 220 }}
      >
        {/* Outer slow-rotate ring */}
        <motion.div
          className="absolute rounded-full border border-primary/15"
          style={{ inset: 0 }}
          animate={{ rotate: 360 }}
          transition={{ duration: 14, repeat: Infinity, ease: "linear" }}
        />

        {/* Middle pulse ring */}
        <motion.div
          className="absolute rounded-full border border-primary/25"
          style={{ inset: 22 }}
          animate={{ scale: [1, 1.12, 1], opacity: [0.25, 0.55, 0.25] }}
          transition={{ duration: 2.4, repeat: Infinity, ease: "easeInOut" }}
        />

        {/* Inner pulse ring */}
        <motion.div
          className="absolute rounded-full border border-secondary/20"
          style={{ inset: 46 }}
          animate={{ scale: [1, 1.08, 1], opacity: [0.2, 0.5, 0.2] }}
          transition={{ duration: 1.8, repeat: Infinity, ease: "easeInOut", delay: 0.6 }}
        />

        {/* Core glass disc */}
        <div
          className="absolute glass-card rounded-full flex items-center justify-center"
          style={{ inset: 70 }}
        >
          <AnimatePresence mode="wait">
            {done ? (
              <motion.div
                key="check"
                initial={{ scale: 0, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                transition={{ type: "spring", stiffness: 260, damping: 20 }}
              >
                <CheckCircle2 className="w-9 h-9 text-primary" />
              </motion.div>
            ) : (
              <motion.div
                key="brain"
                animate={{ opacity: [0.5, 1, 0.5] }}
                transition={{ duration: 2, repeat: Infinity }}
              >
                <Brain className="w-9 h-9 text-primary" />
              </motion.div>
            )}
          </AnimatePresence>
        </div>

        {/* Muse headband SVG overlay */}
        <MuseHeadband progress={progress} />
      </motion.div>

      {/* Step label */}
      <motion.div
        initial={{ y: 16, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.4 }}
        className="text-center space-y-2 mb-8 z-10 w-full max-w-xs"
      >
        <p className="mono text-xs text-muted-foreground uppercase tracking-widest">Muse 2 Headband</p>

        <AnimatePresence mode="wait">
          <motion.p
            key={currentStep.label}
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -6 }}
            transition={{ duration: 0.3 }}
            className={`text-lg font-semibold ${done ? "glow-text-cyan" : "text-foreground"}`}
          >
            {done ? "Calibration Complete" : currentStep.label}
          </motion.p>
        </AnimatePresence>

        <AnimatePresence mode="wait">
          <motion.p
            key={currentStep.detail}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.3 }}
            className="mono text-xs text-muted-foreground"
          >
            {done ? "Launching monitoring interface…" : currentStep.detail}
          </motion.p>
        </AnimatePresence>
      </motion.div>

      {/* Progress bar */}
      <div className="w-full max-w-xs z-10 space-y-2">
        <div className="h-1.5 bg-muted rounded-full overflow-hidden">
          <motion.div
            className="h-full rounded-full"
            style={{
              background: "linear-gradient(90deg, hsl(187 80% 55%), hsl(270 60% 55%))",
              width: `${progress}%`,
            }}
            transition={{ ease: "linear" }}
          />
        </div>

        <div className="flex justify-between items-center">
          <div className="flex gap-3">
            {STEPS.map((s, i) => (
              <motion.div
                key={i}
                className="w-1.5 h-1.5 rounded-full"
                animate={{
                  background: i < stepIndex
                    ? "hsl(187 80% 55%)"
                    : i === stepIndex
                      ? ["hsl(187 80% 55%)", "hsl(270 60% 55%)", "hsl(187 80% 55%)"]
                      : "hsl(230 15% 20%)",
                  scale: i === stepIndex ? [1, 1.4, 1] : 1,
                }}
                transition={{ duration: 1.5, repeat: i === stepIndex ? Infinity : 0 }}
              />
            ))}
          </div>
          <span className="mono text-xs text-primary">{Math.round(progress)}%</span>
        </div>
      </div>
    </motion.div>
  );
}

/* ─── Muse headband SVG with animated signal pulses ─────────────────────── */
function MuseHeadband({ progress }: { progress: number }) {
  return (
    <svg
      viewBox="0 0 260 220"
      className="absolute inset-0 w-full h-full"
      style={{ overflow: "visible" }}
    >
      {/* Arc — the headband bridge */}
      <path
        d="M 30 160 Q 130 20 230 160"
        fill="none"
        stroke="hsl(187 80% 55% / 0.18)"
        strokeWidth="3"
        strokeLinecap="round"
      />

      {/* Animated glowing pulse travelling along the arc */}
      {progress > 0 && (
        <motion.circle
          r="4"
          fill="hsl(187 80% 55%)"
          style={{ filter: "drop-shadow(0 0 6px hsl(187 80% 55%))" }}
          animate={{ offsetDistance: ["0%", "100%"] }}
          transition={{ duration: 1.8, repeat: Infinity, ease: "easeInOut" }}
        >
          <animateMotion
            dur="1.8s"
            repeatCount="indefinite"
            path="M 30 160 Q 130 20 230 160"
          />
        </motion.circle>
      )}

      {/* Second pulse (offset) */}
      {progress > 20 && (
        <motion.circle
          r="3"
          fill="hsl(270 60% 55%)"
          style={{ filter: "drop-shadow(0 0 5px hsl(270 60% 55%))" }}
          animate={{ opacity: [0.6, 1, 0.6] }}
          transition={{ duration: 1.8, repeat: Infinity }}
        >
          <animateMotion
            dur="1.8s"
            begin="0.9s"
            repeatCount="indefinite"
            path="M 30 160 Q 130 20 230 160"
          />
        </motion.circle>
      )}

      {/* Left ear sensor */}
      <Sensor cx={30} cy={160} active={progress > 5}  color="hsl(187 80% 55%)" delay={0}   />
      {/* Right ear sensor */}
      <Sensor cx={230} cy={160} active={progress > 5}  color="hsl(187 80% 55%)" delay={0.3} />
      {/* Forehead sensors */}
      <Sensor cx={100} cy={62}  active={progress > 25} color="hsl(270 60% 55%)" delay={0.6} />
      <Sensor cx={130} cy={42}  active={progress > 35} color="hsl(310 60% 55%)" delay={0.9} />
      <Sensor cx={160} cy={62}  active={progress > 45} color="hsl(270 60% 55%)" delay={1.1} />

      {/* Tiny EEG waveform near each active forehead sensor */}
      {progress > 50 && (
        <>
          <WaveformGlyph x={68} y={55} color="hsl(270 60% 55%)" />
          <WaveformGlyph x={168} y={55} color="hsl(270 60% 55%)" />
        </>
      )}
    </svg>
  );
}

function Sensor({
  cx, cy, active, color, delay,
}: {
  cx: number; cy: number; active: boolean; color: string; delay: number;
}) {
  return (
    <motion.g
      initial={{ scale: 0, opacity: 0 }}
      animate={active ? { scale: 1, opacity: 1 } : { scale: 0, opacity: 0 }}
      transition={{ duration: 0.4, delay }}
      style={{ transformOrigin: `${cx}px ${cy}px` }}
    >
      {/* Halo ring */}
      <motion.circle
        cx={cx} cy={cy} r={10}
        fill="none"
        stroke={color}
        strokeWidth="1"
        opacity={0.3}
        animate={{ r: [8, 14, 8], opacity: [0.4, 0, 0.4] }}
        transition={{ duration: 2, repeat: Infinity, ease: "easeOut", delay }}
      />
      {/* Core dot */}
      <circle cx={cx} cy={cy} r={5} fill={color} opacity={0.85}
        style={{ filter: `drop-shadow(0 0 5px ${color})` }} />
      <circle cx={cx} cy={cy} r={2.5} fill="white" opacity={0.6} />
    </motion.g>
  );
}

function WaveformGlyph({ x, y, color }: { x: number; y: number; color: string }) {
  const pts = `${x},${y} ${x+4},${y-6} ${x+8},${y+6} ${x+12},${y-4} ${x+16},${y}`;
  return (
    <motion.polyline
      points={pts}
      fill="none"
      stroke={color}
      strokeWidth="1.2"
      strokeLinecap="round"
      strokeLinejoin="round"
      opacity={0.7}
      initial={{ pathLength: 0, opacity: 0 }}
      animate={{ pathLength: 1, opacity: 0.7 }}
      transition={{ duration: 0.8, ease: "easeOut" }}
    />
  );
}

/* ─── Background brainwave lines ─────────────────────────────────────────── */
function BrainwaveLines() {
  return (
    <svg
      className="w-full h-full animate-brainwave"
      viewBox="0 0 1200 600"
      preserveAspectRatio="none"
    >
      {[150, 250, 350, 450].map((y, i) => (
        <path
          key={i}
          d={`M0,${y} ${Array.from({ length: 60 }, (_, j) => {
            const x   = j * 40;
            const amp = 15 + i * 5;
            const frq = 0.15 + i * 0.05;
            return `L${x},${y + Math.sin(j * frq) * amp}`;
          }).join(" ")}`}
          fill="none"
          stroke={i % 2 === 0 ? "hsl(187 80% 55%)" : "hsl(270 60% 55%)"}
          strokeWidth="1.5"
        />
      ))}
    </svg>
  );
}
