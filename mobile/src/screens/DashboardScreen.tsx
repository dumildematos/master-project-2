/**
 * DashboardScreen
 * ---------------
 * Main live view — shows the current emotion, EEG band bars, AI guidance
 * sentence, AI pattern info, vitals, and connection status.
 */

import React from "react";
import {
  View, Text, ScrollView, StyleSheet, Dimensions,
} from "react-native";
import { useSentioWebSocket } from "../hooks/useSentioWebSocket";
import { colors, emotionColor, emotionLabel, spacing, radius, font } from "../theme";

const { width } = Dimensions.get("window");

// ---------------------------------------------------------------------------
// Band bar
// ---------------------------------------------------------------------------
function BandBar({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <View style={styles.bandRow}>
      <Text style={styles.bandLabel}>{label}</Text>
      <View style={styles.bandTrack}>
        <View style={[styles.bandFill, { width: `${Math.round(value * 100)}%`, backgroundColor: color }]} />
      </View>
      <Text style={styles.bandValue}>{(value * 100).toFixed(0)}%</Text>
    </View>
  );
}

// ---------------------------------------------------------------------------
// Stat card
// ---------------------------------------------------------------------------
function StatCard({ label, value, unit }: { label: string; value: string | number | null; unit?: string }) {
  return (
    <View style={styles.statCard}>
      <Text style={styles.statLabel}>{label}</Text>
      <Text style={styles.statValue}>
        {value !== null && value !== undefined ? `${value}${unit ?? ""}` : "—"}
      </Text>
    </View>
  );
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
export default function DashboardScreen() {
  const { data, connected, hasSignal } = useSentioWebSocket();
  const emoColor = emotionColor[data.emotion] ?? colors.muted;

  return (
    <ScrollView style={styles.root} contentContainerStyle={styles.content}>

      {/* ── Header ── */}
      <View style={styles.header}>
        <Text style={styles.wordmark}>SENTIO</Text>
        <View style={[styles.dot, { backgroundColor: connected ? colors.cyan : colors.muted }]} />
      </View>

      {/* ── Connection badge ── */}
      {!connected && (
        <View style={styles.offlineBanner}>
          <Text style={styles.offlineText}>Connecting to backend…</Text>
        </View>
      )}

      {/* ── Emotion card ── */}
      <View style={[styles.emotionCard, { borderColor: emoColor + "44" }]}>
        <Text style={styles.emotionTag}>DETECTED EMOTION</Text>
        <Text style={[styles.emotionName, { color: emoColor }]}>
          {emotionLabel[data.emotion] ?? data.emotion.toUpperCase()}
        </Text>
        <View style={styles.confidenceRow}>
          <View style={styles.confidenceTrack}>
            <View
              style={[
                styles.confidenceFill,
                { width: `${Math.round(data.confidence * 100)}%`, backgroundColor: emoColor },
              ]}
            />
          </View>
          <Text style={styles.confidencePct}>{Math.round(data.confidence * 100)}%</Text>
        </View>
        {data.isUncertain && hasSignal && (
          <Text style={styles.uncertainLabel}>Low confidence — uncertain state</Text>
        )}
      </View>

      {/* ── AI Guidance ── */}
      {data.aiGuidance && (
        <View style={styles.guidanceCard}>
          <Text style={styles.guidanceTag}>AI GUIDANCE · claude-haiku-4-5</Text>
          <Text style={styles.guidanceText}>{data.aiGuidance}</Text>
        </View>
      )}

      {/* ── EEG Bands ── */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>EEG BANDS</Text>
        <BandBar label="α Alpha"  value={data.bands.alpha} color={colors.cyan}    />
        <BandBar label="β Beta"   value={data.bands.beta}  color={colors.amber}   />
        <BandBar label="θ Theta"  value={data.bands.theta} color={colors.magenta} />
        <BandBar label="γ Gamma"  value={data.bands.gamma} color="#f97316"        />
        <BandBar label="δ Delta"  value={data.bands.delta} color="#8b5cf6"        />
      </View>

      {/* ── Signal quality ── */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>SIGNAL</Text>
        <View style={styles.statsRow}>
          <StatCard label="Quality"    value={data.signal_quality.toFixed(0)} unit="%" />
          <StatCard label="Mindful"    value={data.mindfulness !== null ? (data.mindfulness * 100).toFixed(0) : null} unit="%" />
          <StatCard label="Restful"    value={data.restfulness !== null ? (data.restfulness * 100).toFixed(0) : null} unit="%" />
        </View>
      </View>

      {/* ── Vitals ── */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>VITALS</Text>
        <View style={styles.statsRow}>
          <StatCard label="Heart BPM"     value={data.vitals.heartBpm?.toFixed(0)         ?? null} />
          <StatCard label="Resp RPM"      value={data.vitals.respirationRpm?.toFixed(1)    ?? null} />
          <StatCard label="HR Conf"       value={data.vitals.heartConfidence !== null ? (data.vitals.heartConfidence * 100).toFixed(0) : null} unit="%" />
        </View>
      </View>

      {/* ── AI Pattern ── */}
      {data.aiPattern && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>AI PATTERN</Text>
          <View style={[styles.patternCard, { borderColor: (data.aiPattern.primary ?? "#fff") + "44" }]}>
            <View style={styles.patternHeader}>
              <Text style={styles.patternType}>{data.aiPattern.pattern_type.toUpperCase()}</Text>
              <View style={styles.swatches}>
                {[data.aiPattern.primary, data.aiPattern.secondary, data.aiPattern.accent, data.aiPattern.shadow].map((c, i) => (
                  <View key={i} style={[styles.swatch, { backgroundColor: c }]} />
                ))}
              </View>
            </View>
            <View style={styles.statsRow}>
              <StatCard label="Speed"      value={(data.aiPattern.speed * 100).toFixed(0)} unit="%" />
              <StatCard label="Complexity" value={(data.aiPattern.complexity * 100).toFixed(0)} unit="%" />
              <StatCard label="Intensity"  value={(data.aiPattern.intensity * 100).toFixed(0)} unit="%" />
            </View>
          </View>
        </View>
      )}

    </ScrollView>
  );
}

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------
const styles = StyleSheet.create({
  root:    { flex: 1, backgroundColor: colors.bg },
  content: { padding: spacing.md, paddingBottom: spacing.xxl },

  header: {
    flexDirection:  "row",
    alignItems:     "center",
    justifyContent: "space-between",
    marginBottom:   spacing.lg,
    paddingTop:     spacing.lg,
  },
  wordmark: {
    fontFamily: font.mono,
    fontSize:   20,
    fontWeight: "700",
    letterSpacing: 4,
    color:      colors.cyan,
  },
  dot: { width: 10, height: 10, borderRadius: 5 },

  offlineBanner: {
    backgroundColor: colors.bg2,
    borderWidth:     1,
    borderColor:     colors.border,
    borderRadius:    radius.md,
    padding:         spacing.sm,
    marginBottom:    spacing.md,
    alignItems:      "center",
  },
  offlineText: { color: colors.muted, fontSize: 13, fontFamily: font.mono },

  emotionCard: {
    backgroundColor: colors.bg2,
    borderWidth:     1,
    borderRadius:    radius.lg,
    padding:         spacing.lg,
    marginBottom:    spacing.md,
  },
  emotionTag: {
    fontFamily:    font.mono,
    fontSize:      10,
    letterSpacing: 2,
    color:         colors.muted,
    marginBottom:  spacing.xs,
  },
  emotionName: {
    fontSize:      40,
    fontWeight:    "800",
    letterSpacing: 1,
    marginBottom:  spacing.md,
  },
  confidenceRow:  { flexDirection: "row", alignItems: "center", gap: spacing.sm },
  confidenceTrack: { flex: 1, height: 6, backgroundColor: colors.border, borderRadius: radius.full, overflow: "hidden" },
  confidenceFill:  { height: "100%", borderRadius: radius.full },
  confidencePct:   { fontFamily: font.mono, fontSize: 12, color: colors.muted, width: 36, textAlign: "right" },
  uncertainLabel:  { marginTop: spacing.sm, fontSize: 12, color: colors.muted, fontFamily: font.mono },

  guidanceCard: {
    backgroundColor: colors.bg2,
    borderWidth:     1,
    borderColor:     colors.magenta + "33",
    borderRadius:    radius.lg,
    padding:         spacing.md,
    marginBottom:    spacing.md,
  },
  guidanceTag:  { fontFamily: font.mono, fontSize: 10, letterSpacing: 2, color: colors.magenta, marginBottom: spacing.sm },
  guidanceText: { fontSize: 15, color: colors.text, lineHeight: 22, fontStyle: "italic" },

  section:      { marginBottom: spacing.md },
  sectionTitle: { fontFamily: font.mono, fontSize: 10, letterSpacing: 2, color: colors.muted, marginBottom: spacing.sm },

  bandRow:   { flexDirection: "row", alignItems: "center", marginBottom: spacing.xs },
  bandLabel: { fontFamily: font.mono, fontSize: 11, color: colors.muted, width: 72 },
  bandTrack: { flex: 1, height: 6, backgroundColor: colors.border, borderRadius: radius.full, overflow: "hidden", marginHorizontal: spacing.sm },
  bandFill:  { height: "100%", borderRadius: radius.full },
  bandValue: { fontFamily: font.mono, fontSize: 11, color: colors.muted, width: 34, textAlign: "right" },

  statsRow: { flexDirection: "row", gap: spacing.sm },
  statCard: {
    flex:            1,
    backgroundColor: colors.bg2,
    borderWidth:     1,
    borderColor:     colors.border,
    borderRadius:    radius.md,
    padding:         spacing.sm,
    alignItems:      "center",
  },
  statLabel: { fontFamily: font.mono, fontSize: 9,  color: colors.muted, letterSpacing: 1, marginBottom: 4 },
  statValue: { fontFamily: font.mono, fontSize: 16, color: colors.text,  fontWeight: "700" },

  patternCard: {
    backgroundColor: colors.bg2,
    borderWidth:     1,
    borderRadius:    radius.md,
    padding:         spacing.md,
    gap:             spacing.sm,
  },
  patternHeader:  { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  patternType:    { fontFamily: font.mono, fontSize: 14, fontWeight: "700", color: colors.text, letterSpacing: 2 },
  swatches:       { flexDirection: "row", gap: 6 },
  swatch:         { width: 20, height: 20, borderRadius: 4 },
});
