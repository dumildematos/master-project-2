import React from "react";
import { colors, spacing, radius } from "../theme";

export default function ConnectionBanner({
  connected, hasSignal,
}: { connected: boolean; hasSignal: boolean }) {
  if (connected && hasSignal) return null;

  const isWaiting = connected && !hasSignal;
  const dotColor  = isWaiting ? colors.amber : colors.muted;

  return (
    <div style={{
      display: "flex", alignItems: "flex-start", gap: 8,
      background: colors.bg2,
      border: `1px solid ${isWaiting ? `${colors.amber}44` : colors.border}`,
      borderRadius: radius.md, padding: spacing.sm, marginBottom: spacing.md,
    }}>
      <div style={{ width: 8, height: 8, borderRadius: 4, background: dotColor, marginTop: 3, flexShrink: 0 }} />
      <div>
        <p style={{ color: colors.text, fontSize: 12, fontFamily: "monospace", margin: 0 }}>
          {!connected
            ? "Not connected — check backend address in Settings"
            : "Connected · no EEG stream active"}
        </p>
        {isWaiting && (
          <p style={{ color: colors.muted, fontSize: 11, fontFamily: "monospace", marginTop: 4, lineHeight: 1.5, marginBottom: 0 }}>
            Go to Settings → Demo Mode to inject a test signal, or start a session from the web dashboard.
          </p>
        )}
      </div>
    </div>
  );
}
