import React from "react";
import { motion, AnimatePresence } from "framer-motion";

const BAND_META = [
  { key: "alpha", label: "α Alpha", range: "8–12 Hz",  color: "hsl(187 80% 55%)" },
  { key: "beta",  label: "β Beta",  range: "13–30 Hz", color: "hsl(310 60% 55%)" },
  { key: "theta", label: "θ Theta", range: "4–7 Hz",   color: "hsl(270 60% 55%)" },
  { key: "gamma", label: "γ Gamma", range: "31–50 Hz", color: "hsl(45 90% 60%)"  },
  { key: "delta", label: "δ Delta", range: "0.5–3 Hz", color: "hsl(220 70% 55%)" },
];

interface Props {
  bands:     Record<string, number>;
  hasSignal: boolean;
}

export default function BandCards({ bands, hasSignal }: Props) {
  return (
    <div className="grid grid-cols-5 gap-2">
      {BAND_META.map(({ key, label, range, color }, i) => {
        const pct = ((bands[key] ?? 0) * 100).toFixed(1);
        return (
          <motion.div
            key={key}
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.06 }}
            className="glass-card p-3 flex flex-col gap-1.5"
            style={{ boxShadow: `0 0 18px -8px ${color}${hasSignal ? "88" : "33"}` }}
          >
            <p className="mono text-[9px] font-medium uppercase tracking-widest truncate"
               style={{ color, opacity: hasSignal ? 1 : 0.5 }}>
              {label}
            </p>

            <AnimatePresence mode="wait">
              {hasSignal ? (
                <motion.p
                  key={`val-${pct}`}
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  className="text-xl font-bold leading-none"
                  style={{ color }}
                >
                  {pct}
                  <span className="text-[10px] font-normal text-muted-foreground ml-0.5">%</span>
                </motion.p>
              ) : (
                <motion.p
                  key="placeholder"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: [0.3, 0.7, 0.3] }}
                  transition={{ duration: 1.6, repeat: Infinity, ease: "easeInOut", delay: i * 0.12 }}
                  className="text-xl font-bold leading-none text-muted-foreground/40 mono"
                >
                  —
                </motion.p>
              )}
            </AnimatePresence>

            <p className="mono text-[9px] text-muted-foreground">{range}</p>

            {/* Bar indicator */}
            <div className="h-0.5 rounded-full bg-muted/30 overflow-hidden mt-0.5">
              <motion.div
                className="h-full rounded-full"
                style={{ background: color }}
                animate={{ width: hasSignal ? `${pct}%` : "0%" }}
                transition={{ duration: 0.3 }}
              />
            </div>
          </motion.div>
        );
      })}
    </div>
  );
}
