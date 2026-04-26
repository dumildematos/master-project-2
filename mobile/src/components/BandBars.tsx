import React from "react";
import { colors, spacing } from "../theme";

const BANDS = [
  { key: "alpha", label: "α  Alpha", color: colors.cyan,    desc: "calm / relaxed" },
  { key: "beta",  label: "β  Beta",  color: colors.amber,   desc: "focus / alertness" },
  { key: "theta", label: "θ  Theta", color: colors.magenta, desc: "creativity / drowsiness" },
  { key: "gamma", label: "γ  Gamma", color: "#f97316",      desc: "cognition / excitement" },
  { key: "delta", label: "δ  Delta", color: "#8b5cf6",      desc: "deep rest" },
] as const;

interface Props {
  bands: { alpha: number; beta: number; theta: number; gamma: number; delta: number };
  showDesc?: boolean;
}

export default function BandBars({ bands, showDesc = false }: Props) {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: spacing.sm }}>
      {BANDS.map(({ key, label, color, desc }) => {
        const value = bands[key] ?? 0;
        const pct   = Math.min(100, Math.round(value * 100));
        return (
          <div key={key} style={{ display: "flex", alignItems: "center", gap: spacing.sm }}>
            <div style={{ width: 90 }}>
              <span style={{ fontFamily: "monospace", fontSize: 12, color: colors.text }}>{label}</span>
              {showDesc && (
                <p style={{ fontFamily: "monospace", fontSize: 9, color: colors.muted, marginTop: 1, margin: 0 }}>
                  {desc}
                </p>
              )}
            </div>
            <div style={{
              flex: 1, height: 7, background: colors.border,
              borderRadius: 999, overflow: "hidden",
            }}>
              <div style={{
                width: `${pct}%`, height: "100%",
                background: color, borderRadius: 999,
                transition: "width .3s ease",
              }} />
            </div>
            <span style={{
              fontFamily: "monospace", fontSize: 12, color: colors.muted,
              width: 36, textAlign: "right",
            }}>
              {pct}%
            </span>
          </div>
        );
      })}
    </div>
  );
}
