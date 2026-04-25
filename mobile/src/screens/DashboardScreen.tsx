/**
 * DashboardScreen — improved v2
 * Live emotion ring, AI guidance, EEG bands, AI pattern, vitals.
 */
import React from "react";
import { View, Text, ScrollView, StyleSheet } from "react-native";
import { useSentio } from "../lib/SentioContext";
import EmotionRing     from "../components/EmotionRing";
import BandBars        from "../components/BandBars";
import StatRow         from "../components/StatRow";
import ConnectionBanner from "../components/ConnectionBanner";
import { colors, spacing, radius, font } from "../theme";

export default function DashboardScreen() {
  const { data, connected, hasSignal } = useSentio();

  return (
    <ScrollView style={styles.root} contentContainerStyle={styles.content}>

      <ConnectionBanner connected={connected} hasSignal={hasSignal} />

      {/* ── Emotion ring ── */}
      <View style={styles.ringWrap}>
        <EmotionRing
          emotion={data.emotion}
          confidence={data.confidence}
          size={220}
        />
        {data.isUncertain && hasSignal && (
          <Text style={styles.uncertainLabel}>Low confidence — uncertain state</Text>
        )}
      </View>

      {/* ── AI Guidance ── */}
      {data.aiGuidance ? (
        <View style={styles.guidanceCard}>
          <Text style={styles.guidanceTag}>✦ AI GUIDANCE · claude-haiku-4-5</Text>
          <Text style={styles.guidanceText}>{data.aiGuidance}</Text>
        </View>
      ) : (
        <View style={[styles.guidanceCard, styles.guidanceMuted]}>
          <Text style={styles.guidanceTag}>✦ AI GUIDANCE</Text>
          <Text style={[styles.guidanceText, { color: colors.muted }]}>
            {connected ? "Generating guidance…" : "Not connected"}
          </Text>
        </View>
      )}

      {/* ── EEG Bands ── */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>EEG BANDS</Text>
        <BandBars bands={data.bands} />
      </View>

      {/* ── Signal ── */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>SIGNAL</Text>
        <StatRow items={[
          { label: "QUALITY",    value: data.signal_quality.toFixed(0), unit: "%" },
          { label: "MINDFUL",    value: data.mindfulness !== null ? (data.mindfulness * 100).toFixed(0) : null, unit: "%" },
          { label: "RESTFUL",    value: data.restfulness !== null ? (data.restfulness * 100).toFixed(0) : null, unit: "%" },
        ]} />
      </View>

      {/* ── Vitals ── */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>VITALS</Text>
        <StatRow items={[
          { label: "HEART BPM",  value: data.vitals.heartBpm?.toFixed(0) ?? null },
          { label: "RESP RPM",   value: data.vitals.respirationRpm?.toFixed(1) ?? null },
          { label: "HR CONF",    value: data.vitals.heartConfidence !== null ? (data.vitals.heartConfidence * 100).toFixed(0) : null, unit: "%" },
        ]} />
      </View>

      {/* ── AI Pattern ── */}
      {data.aiPattern && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>AI PATTERN</Text>
          <View style={[styles.patternCard, { borderColor: data.aiPattern.primary + "44" }]}>
            <View style={styles.patternHeader}>
              <Text style={styles.patternType}>{data.aiPattern.pattern_type.toUpperCase()}</Text>
              <View style={styles.swatches}>
                {[data.aiPattern.primary, data.aiPattern.secondary, data.aiPattern.accent, data.aiPattern.shadow].map((c, i) => (
                  <View key={i} style={[styles.swatch, { backgroundColor: c }]} />
                ))}
              </View>
            </View>
            <StatRow items={[
              { label: "SPEED",      value: (data.aiPattern.speed * 100).toFixed(0), unit: "%" },
              { label: "COMPLEXITY", value: (data.aiPattern.complexity * 100).toFixed(0), unit: "%" },
              { label: "INTENSITY",  value: (data.aiPattern.intensity * 100).toFixed(0), unit: "%" },
            ]} />
          </View>
        </View>
      )}

    </ScrollView>
  );
}

const styles = StyleSheet.create({
  root:    { flex: 1, backgroundColor: colors.bg },
  content: { padding: spacing.md, paddingBottom: 48 },

  ringWrap: { alignItems: "center", marginVertical: spacing.lg },
  uncertainLabel: {
    marginTop:  spacing.sm,
    fontSize:   12,
    color:      colors.muted,
    fontFamily: font.mono,
    textAlign:  "center",
  },

  guidanceCard: {
    backgroundColor: colors.bg2,
    borderWidth:     1,
    borderColor:     colors.magenta + "33",
    borderRadius:    radius.lg,
    padding:         spacing.md,
    marginBottom:    spacing.md,
  },
  guidanceMuted: { borderColor: colors.border },
  guidanceTag: {
    fontFamily:   font.mono,
    fontSize:     10,
    letterSpacing: 2,
    color:        colors.magenta,
    marginBottom: spacing.sm,
  },
  guidanceText: { fontSize: 15, color: colors.text, lineHeight: 23, fontStyle: "italic" },

  section:      { marginBottom: spacing.md },
  sectionTitle: {
    fontFamily:    font.mono,
    fontSize:      10,
    letterSpacing: 2,
    color:         colors.muted,
    marginBottom:  spacing.sm,
  },

  patternCard: {
    backgroundColor: colors.bg2,
    borderWidth:     1,
    borderRadius:    radius.md,
    padding:         spacing.md,
    gap:             spacing.sm,
  },
  patternHeader:  { flexDirection: "row", alignItems: "center", justifyContent: "space-between", marginBottom: spacing.sm },
  patternType:    { fontFamily: font.mono, fontSize: 14, fontWeight: "700", color: colors.text, letterSpacing: 2 },
  swatches:       { flexDirection: "row", gap: 6 },
  swatch:         { width: 20, height: 20, borderRadius: 4 },
});
