import React from "react";
import { colors, spacing, radius } from "../theme";

interface StatItem {
  label: string;
  value: string | number | null | undefined;
  unit?:  string;
  color?: string;
}

export default function StatRow({ items }: { items: StatItem[] }) {
  return (
    <div style={{ display: "flex", gap: spacing.sm }}>
      {items.map(({ label, value, unit, color }) => (
        <div key={label} style={{
          flex: 1, background: colors.bg2,
          border: `1px solid ${colors.border}`, borderRadius: radius.md,
          padding: spacing.sm, textAlign: "center",
        }}>
          <p style={{
            fontFamily: "monospace", fontSize: 9, color: colors.muted,
            letterSpacing: 1, marginBottom: 4, margin: 0,
          }}>
            {label}
          </p>
          <p style={{
            fontFamily: "monospace", fontSize: 17, color: color ?? colors.text,
            fontWeight: 700, margin: 0, marginTop: 4,
          }}>
            {value !== null && value !== undefined && value !== ""
              ? `${value}${unit ?? ""}`
              : "—"}
          </p>
        </div>
      ))}
    </div>
  );
}
