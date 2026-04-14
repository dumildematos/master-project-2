import React from "react";
import { motion } from "framer-motion";
import { SentioState } from "../hooks/useWebSocket";

const PARAM_META: Record<string, { label: string; unit: string; max: number; color: string }> = {
  colorHue:        { label: "Color Hue",         unit: "°",  max: 360, color: "hsl(var(--glow-cyan))"    },
  flowSpeed:       { label: "Flow Speed",         unit: "",   max: 1,   color: "hsl(var(--glow-purple))"  },
  distortion:      { label: "Distortion",         unit: "",   max: 1,   color: "hsl(var(--glow-magenta))" },
  particleDensity: { label: "Particle Density",   unit: "",   max: 1,   color: "hsl(220 70% 55%)"         },
  brightness:      { label: "Brightness",         unit: "",   max: 1,   color: "hsl(45 90% 60%)"          },
};

export default function DesignParams({ params }: { params: SentioState["params"] }) {
  return (
    <div className="glass-card p-5 flex flex-col gap-4">
      <p className="text-xs font-semibold tracking-widest text-muted-foreground uppercase">
        Visual Parameters
      </p>

      {Object.entries(params).map(([key, value], i) => {
        const meta = PARAM_META[key];
        if (!meta) return null;
        const pct = (value / meta.max) * 100;

        return (
          <motion.div
            key={key}
            initial={{ opacity: 0, x: -10 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: i * 0.05 }}
            className="flex flex-col gap-1.5"
          >
            <div className="flex justify-between items-center">
              <span className="text-xs text-muted-foreground">{meta.label}</span>
              <span className="mono text-xs" style={{ color: meta.color }}>
                {meta.unit === "°"
                  ? `${Math.round(value)}°`
                  : value.toFixed(2)}
              </span>
            </div>
            <div className="h-1.5 rounded-full bg-muted overflow-hidden">
              <motion.div
                className="h-full rounded-full"
                style={{ background: meta.color }}
                animate={{ width: `${pct}%` }}
                transition={{ duration: 0.5, ease: "easeOut" }}
              />
            </div>
          </motion.div>
        );
      })}
    </div>
  );
}
