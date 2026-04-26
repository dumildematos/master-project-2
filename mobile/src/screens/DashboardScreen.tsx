/**
 * DashboardScreen  (Ionic)
 * Live emotion ring, AI guidance, EEG bands, AI pattern, vitals.
 */
import React from "react";
import { IonPage, IonContent } from "@ionic/react";
import { useSentio } from "../lib/SentioContext";
import EmotionRing     from "../components/EmotionRing";
import BandBars        from "../components/BandBars";
import StatRow         from "../components/StatRow";
import ConnectionBanner from "../components/ConnectionBanner";
import { colors, spacing, radius } from "../theme";

const s = {
  content: { background: colors.bg },
  scroll:  { padding: `${spacing.md}px`, paddingBottom: 48 },
  ringWrap: { display: "flex", flexDirection: "column" as const, alignItems: "center", margin: `${spacing.lg}px 0` },
  uncertainLabel: {
    marginTop: spacing.sm, fontSize: 12, color: colors.muted,
    fontFamily: "monospace", textAlign: "center" as const,
  },
  guidanceCard: (muted: boolean) => ({
    background: colors.bg2, borderRadius: radius.lg,
    border: `1px solid ${muted ? colors.border : `${colors.magenta}33`}`,
    padding: spacing.md, marginBottom: spacing.md,
  }),
  guidanceTag: {
    fontFamily: "monospace", fontSize: 10, letterSpacing: 2,
    color: colors.magenta, marginBottom: spacing.sm, display: "block",
  },
  guidanceText: (muted: boolean) => ({
    fontSize: 15, color: muted ? colors.muted : colors.text,
    lineHeight: 1.55, fontStyle: "italic" as const, margin: 0,
  }),
  section:      { marginBottom: spacing.md },
  sectionTitle: {
    fontFamily: "monospace", fontSize: 10, letterSpacing: 2,
    color: colors.muted, marginBottom: spacing.sm, display: "block",
  },
  patternCard: (borderCol: string) => ({
    background: colors.bg2, borderRadius: radius.md,
    border: `1px solid ${borderCol}44`,
    padding: spacing.md, display: "flex", flexDirection: "column" as const, gap: spacing.sm,
  }),
  patternHeader: {
    display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: spacing.sm,
  },
  patternType: {
    fontFamily: "monospace", fontSize: 14, fontWeight: 700,
    color: colors.text, letterSpacing: 2,
  },
  swatches:  { display: "flex", gap: 6 },
  swatch:    { width: 20, height: 20, borderRadius: 4 },
} as const;

export default function DashboardScreen() {
  const { data, connected, hasSignal } = useSentio();

  return (
    <IonPage>
      <IonContent style={{ "--background": colors.bg }}>
        <div style={s.scroll}>
          <ConnectionBanner connected={connected} hasSignal={hasSignal} />

          {/* Emotion ring */}
          <div style={s.ringWrap}>
            <EmotionRing emotion={data.emotion} confidence={data.confidence / 100} size={220} />
            {data.isUncertain && hasSignal && (
              <p style={s.uncertainLabel}>Low confidence — uncertain state</p>
            )}
          </div>

          {/* AI Guidance */}
          <div style={s.guidanceCard(!data.aiGuidance)}>
            <span style={s.guidanceTag}>✦ AI GUIDANCE · claude-haiku-4-5</span>
            <p style={s.guidanceText(!data.aiGuidance)}>
              {data.aiGuidance
                ? data.aiGuidance
                : connected ? "Generating guidance…" : "Not connected"}
            </p>
          </div>

          {/* EEG Bands */}
          <div style={s.section}>
            <span style={s.sectionTitle}>EEG BANDS</span>
            <BandBars bands={data.bands} />
          </div>

          {/* Signal */}
          <div style={s.section}>
            <span style={s.sectionTitle}>SIGNAL</span>
            <StatRow items={[
              { label: "QUALITY",  value: data.signal_quality.toFixed(0), unit: "%" },
              { label: "MINDFUL",  value: data.mindfulness !== null ? (data.mindfulness * 100).toFixed(0) : null, unit: "%" },
              { label: "RESTFUL",  value: data.restfulness !== null ? (data.restfulness * 100).toFixed(0) : null, unit: "%" },
            ]} />
          </div>

          {/* Vitals */}
          <div style={s.section}>
            <span style={s.sectionTitle}>VITALS</span>
            <StatRow items={[
              { label: "HEART BPM", value: data.vitals.heartBpm?.toFixed(0) ?? null },
              { label: "RESP RPM",  value: data.vitals.respirationRpm?.toFixed(1) ?? null },
              { label: "HR CONF",   value: data.vitals.heartConfidence !== null ? (data.vitals.heartConfidence * 100).toFixed(0) : null, unit: "%" },
            ]} />
          </div>

          {/* AI Pattern */}
          {data.aiPattern && (
            <div style={s.section}>
              <span style={s.sectionTitle}>AI PATTERN</span>
              <div style={s.patternCard(data.aiPattern.primary)}>
                <div style={s.patternHeader}>
                  <span style={s.patternType}>{data.aiPattern.pattern_type.toUpperCase()}</span>
                  <div style={s.swatches}>
                    {[data.aiPattern.primary, data.aiPattern.secondary, data.aiPattern.accent, data.aiPattern.shadow].map((c, i) => (
                      <div key={i} style={{ ...s.swatch, background: c }} />
                    ))}
                  </div>
                </div>
                <StatRow items={[
                  { label: "SPEED",      value: (data.aiPattern.speed * 100).toFixed(0), unit: "%" },
                  { label: "COMPLEXITY", value: (data.aiPattern.complexity * 100).toFixed(0), unit: "%" },
                  { label: "INTENSITY",  value: (data.aiPattern.intensity * 100).toFixed(0), unit: "%" },
                ]} />
              </div>
            </div>
          )}
        </div>
      </IonContent>
    </IonPage>
  );
}
