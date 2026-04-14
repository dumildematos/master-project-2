import React from "react";
import { motion } from "framer-motion";

const BAND_META = [
  { key: "alpha", label: "α Alpha", range: "8–12 Hz",  color: "hsl(187 80% 55%)" },
  { key: "beta",  label: "β Beta",  range: "13–30 Hz", color: "hsl(310 60% 55%)" },
  { key: "theta", label: "θ Theta", range: "4–7 Hz",   color: "hsl(270 60% 55%)" },
  { key: "gamma", label: "γ Gamma", range: "31–50 Hz", color: "hsl(45 90% 60%)"  },
  { key: "delta", label: "δ Delta", range: "0.5–3 Hz", color: "hsl(220 70% 55%)" },
];

export default function BandCards({ bands }: { bands: Record<string, number> }) {
  return (
    <div className="grid grid-cols-5 gap-2">
      {BAND_META.map(({ key, label, range, color }, i) => (
        <motion.div
          key={key}
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: i * 0.06 }}
          className="glass-card p-3 flex flex-col gap-1.5"
          style={{ boxShadow: `0 0 18px -8px ${color}55` }}
        >
          <p className="mono text-[9px] font-medium uppercase tracking-widest truncate"
             style={{ color }}>
            {label}
          </p>
          <p className="text-xl font-bold leading-none" style={{ color }}>
            {((bands[key] ?? 0) * 100).toFixed(1)}
            <span className="text-[10px] font-normal text-muted-foreground ml-0.5">%</span>
          </p>
          <p className="mono text-[9px] text-muted-foreground">{range}</p>
        </motion.div>
      ))}
    </div>
  );
}
