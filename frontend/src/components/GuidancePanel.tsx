import React from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Brain, Wifi, WifiOff, Radio } from "lucide-react";

interface Props {
  guidance:      string;
  emotion:       string;
  connected:     boolean;
  hasSignal:     boolean;   // true once real EEG frames have arrived
}

type Status = "offline" | "waiting" | "live";

function getStatus(connected: boolean, hasSignal: boolean): Status {
  if (!connected)  return "offline";
  if (!hasSignal)  return "waiting";
  return "live";
}

const STATUS_CONFIG = {
  offline: {
    icon:      WifiOff,
    label:     "OFFLINE",
    iconClass: "text-red-400",
    textClass: "text-red-400",
    tip:       "Connecting to backend…",
  },
  waiting: {
    icon:      Radio,
    label:     "WAITING",
    iconClass: "text-yellow-400",
    textClass: "text-yellow-400",
    tip:       "Connected — waiting for EEG stream to start…",
  },
  live: {
    icon:      Wifi,
    label:     "LIVE",
    iconClass: "text-green-400",
    textClass: "text-green-400",
    tip:       null,
  },
} as const;

export default function GuidancePanel({ guidance, emotion, connected, hasSignal }: Props) {
  const status = getStatus(connected, hasSignal);
  const cfg    = STATUS_CONFIG[status];
  const Icon   = cfg.icon;
  const normalizedGuidance = typeof guidance === "string" ? guidance.trim() : "";
  const fallbackGuidance = emotion
    ? `Live state: ${emotion}. Guidance will appear as the stream stabilizes.`
    : "Guidance will appear once the stream begins producing live emotion data.";

  // Show guidance text only when live, otherwise show the status tip
  const displayText = status === "live"
    ? (normalizedGuidance || fallbackGuidance)
    : cfg.tip!;

  return (
    <div className="glass-card-purple gradient-border p-5 flex gap-4 items-start min-h-[120px]">
      {/* Brain icon */}
      <div className="mt-0.5 shrink-0">
        <motion.div
          animate={{ opacity: status === "live" ? [0.4, 1, 0.4] : 0.5 }}
          transition={{ duration: 2, repeat: Infinity, ease: "easeInOut" }}
        >
          <Brain size={20} className="glow-text-purple" />
        </motion.div>
      </div>

      {/* Text */}
      <div className="flex-1 min-w-0">
        <p className="text-[11px] font-semibold tracking-widest text-foreground/70 uppercase mb-1.5">
          AI Guidance
        </p>
        <p className="mono text-[10px] text-primary/80 uppercase tracking-wider mb-2">
          {status === "live" ? `State ${emotion || "unknown"}` : cfg.label}
        </p>
        <AnimatePresence mode="wait">
          <motion.p
            key={displayText}
            initial={{ opacity: 0, y: 4 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -4 }}
            transition={{ duration: 0.35 }}
            className={`text-sm leading-relaxed ${
              status === "live"
                ? "text-foreground font-medium"
                : "text-foreground/70 italic"
            }`}
          >
            {displayText}
          </motion.p>
        </AnimatePresence>
      </div>

      {/* Status badge */}
      <div className="shrink-0 flex items-center gap-1.5 mt-0.5">
        <motion.div
          animate={status === "waiting"
            ? { opacity: [0.4, 1, 0.4] }
            : { opacity: 1 }
          }
          transition={{ duration: 1.2, repeat: Infinity }}
        >
          <Icon size={14} className={cfg.iconClass} />
        </motion.div>
        <span className={`mono text-[10px] font-medium ${cfg.textClass}`}>
          {cfg.label}
        </span>
      </div>
    </div>
  );
}
