/**
 * HistoryScreen  (Ionic)
 * Scrollable EEG band sparklines + emotion timeline.
 */
import React from "react";
import { IonPage, IonContent } from "@ionic/react";
import { useSentio } from "../lib/SentioContext";
import ConnectionBanner from "../components/ConnectionBanner";
import { colors, emotionColor, emotionLabel, spacing, radius } from "../theme";

// ---------------------------------------------------------------------------
// Sparkline chart for one EEG band
// ---------------------------------------------------------------------------
const BAND_META = [
  { key: "alpha", label: "α Alpha", color: colors.cyan    },
  { key: "beta",  label: "β Beta",  color: colors.amber   },
  { key: "theta", label: "θ Theta", color: colors.magenta },
  { key: "gamma", label: "γ Gamma", color: "#f97316"      },
  { key: "delta", label: "δ Delta", color: "#8b5cf6"      },
] as const;
type BandKey = "alpha" | "beta" | "theta" | "gamma" | "delta";

const CHART_H = 60;
const BAR_GAP = 2;

function Sparkline({ band, data, color }: { band: BandKey; data: Record<string, number>[]; color: string }) {
  if (data.length === 0) return null;
  const barW   = Math.max(2, Math.floor((300 - (data.length - 1) * BAR_GAP) / data.length));

  return (
    <div style={{ display: "flex", alignItems: "flex-end", height: CHART_H, overflow: "hidden" }}>
      {data.map((entry, i) => {
        const val  = (entry[band] ?? 0) as number;
        const barH = Math.max(2, Math.round(val * CHART_H));
        return (
          <div
            key={i}
            style={{
              width: barW, height: barH, background: color,
              borderRadius: 1, opacity: 0.55 + val * 0.45,
              marginRight: i < data.length - 1 ? BAR_GAP : 0,
              alignSelf: "flex-end", flexShrink: 0,
            }}
          />
        );
      })}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Emotion pill
// ---------------------------------------------------------------------------
function EmotionPill({ emotion, confidence, t }: { emotion: string; confidence: number; t: number }) {
  const col  = emotionColor[emotion.toLowerCase()] ?? colors.muted;
  const time = new Date(t).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" });
  return (
    <div style={{
      display: "flex", alignItems: "center", gap: spacing.sm,
      background: colors.bg2, border: `1px solid ${col}44`,
      borderRadius: radius.md, padding: spacing.sm, marginBottom: spacing.xs,
    }}>
      <div style={{ width: 8, height: 8, borderRadius: 4, background: col, flexShrink: 0 }} />
      <span style={{ fontFamily: "monospace", fontSize: 13, fontWeight: 700, color: col, flex: 1 }}>
        {emotionLabel[emotion.toLowerCase()] ?? emotion}
      </span>
      <span style={{ fontFamily: "monospace", fontSize: 12, color: colors.muted }}>
        {Math.round(confidence)}%
      </span>
      <span style={{ fontFamily: "monospace", fontSize: 11, color: colors.muted }}>{time}</span>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
export default function HistoryScreen() {
  const { connected, hasSignal, history, emotionHistory } = useSentio();
  const recentHistory = history.slice(-60);

  const sectionTitle: React.CSSProperties = {
    fontFamily: "monospace", fontSize: 10, letterSpacing: 2,
    color: colors.muted, marginBottom: spacing.sm, display: "block",
  };
  const empty: React.CSSProperties = {
    color: colors.muted, fontFamily: "monospace", fontSize: 13, padding: `${spacing.sm}px 0`,
  };

  return (
    <IonPage>
      <IonContent style={{ "--background": colors.bg }}>
        <div style={{ padding: spacing.md, paddingBottom: 48 }}>
          <ConnectionBanner connected={connected} hasSignal={hasSignal} />

          {/* EEG Band Charts */}
          <div style={{ marginBottom: spacing.lg }}>
            <span style={sectionTitle}>
              EEG BAND HISTORY · last {recentHistory.length} frames
            </span>
            {recentHistory.length === 0 ? (
              <p style={empty}>No data yet — waiting for EEG signal…</p>
            ) : (
              <div style={{
                background: colors.bg2, border: `1px solid ${colors.border}`,
                borderRadius: radius.md, padding: spacing.md,
                display: "flex", flexDirection: "column", gap: spacing.sm,
              }}>
                {BAND_META.map(({ key, label, color }) => (
                  <div key={key} style={{ gap: 4 }}>
                    <span style={{ fontFamily: "monospace", fontSize: 11, color, display: "block", marginBottom: 4 }}>
                      {label}
                    </span>
                    <Sparkline band={key} data={recentHistory} color={color} />
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Emotion Timeline */}
          <div style={{ marginBottom: spacing.lg }}>
            <span style={sectionTitle}>
              EMOTION TIMELINE · last {emotionHistory.length} changes
            </span>
            {emotionHistory.length === 0 ? (
              <p style={empty}>No emotion changes recorded yet…</p>
            ) : (
              [...emotionHistory].reverse().map((entry, i) => (
                <EmotionPill key={i} {...entry} />
              ))
            )}
          </div>
        </div>
      </IonContent>
    </IonPage>
  );
}
