/**
 * HistoryScreen
 * -------------
 * Scrollable timeline of the last 20 detected emotions + a simple
 * sparkline chart for each EEG band built from the rolling band history.
 * No chart library needed — we draw bars manually with Views.
 */
import React from "react";
import {
  View, Text, ScrollView, StyleSheet, Dimensions,
} from "react-native";
import { useSentio } from "../lib/SentioContext";
import ConnectionBanner from "../components/ConnectionBanner";
import { colors, emotionColor, emotionLabel, spacing, radius, font } from "../theme";

const { width } = Dimensions.get("window");
const CHART_W   = width - spacing.md * 2 - 2;  // full width minus padding + border
const CHART_H   = 60;
const BAR_GAP   = 2;

// ---------------------------------------------------------------------------
// Mini sparkline for one band
// ---------------------------------------------------------------------------
const BAND_META = [
  { key: "alpha", label: "α Alpha", color: colors.cyan    },
  { key: "beta",  label: "β Beta",  color: colors.amber   },
  { key: "theta", label: "θ Theta", color: colors.magenta },
  { key: "gamma", label: "γ Gamma", color: "#f97316"      },
  { key: "delta", label: "δ Delta", color: "#8b5cf6"      },
] as const;

type BandKey = "alpha" | "beta" | "theta" | "gamma" | "delta";

function Sparkline({ band, data, color }: { band: BandKey; data: { [k: string]: number }[]; color: string }) {
  if (data.length === 0) return null;

  const barW = Math.max(2, Math.floor((CHART_W - (data.length - 1) * BAR_GAP) / data.length));
  const totalW = data.length * (barW + BAR_GAP) - BAR_GAP;

  return (
    <View style={[sparkStyles.row, { width: totalW }]}>
      {data.map((entry, i) => {
        const val = (entry[band] ?? 0) as number;
        const barH = Math.max(2, Math.round(val * CHART_H));
        return (
          <View
            key={i}
            style={{
              width:           barW,
              height:          barH,
              backgroundColor: color,
              borderRadius:    1,
              alignSelf:       "flex-end",
              marginRight:     i < data.length - 1 ? BAR_GAP : 0,
              opacity:         0.55 + val * 0.45,
            }}
          />
        );
      })}
    </View>
  );
}

const sparkStyles = StyleSheet.create({
  row: { flexDirection: "row", alignItems: "flex-end", height: CHART_H },
});

// ---------------------------------------------------------------------------
// Emotion history pill
// ---------------------------------------------------------------------------
function EmotionPill({ emotion, confidence, t }: { emotion: string; confidence: number; t: number }) {
  const col  = emotionColor[emotion] ?? colors.muted;
  const time = new Date(t).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" });
  return (
    <View style={[pillStyles.pill, { borderColor: col + "44" }]}>
      <View style={[pillStyles.dot, { backgroundColor: col }]} />
      <Text style={[pillStyles.name, { color: col }]}>{emotionLabel[emotion] ?? emotion}</Text>
      <Text style={pillStyles.conf}>{Math.round(confidence * 100)}%</Text>
      <Text style={pillStyles.time}>{time}</Text>
    </View>
  );
}

const pillStyles = StyleSheet.create({
  pill: {
    flexDirection:   "row",
    alignItems:      "center",
    gap:             spacing.sm,
    backgroundColor: colors.bg2,
    borderWidth:     1,
    borderRadius:    radius.md,
    padding:         spacing.sm,
    marginBottom:    spacing.xs,
  },
  dot:  { width: 8, height: 8, borderRadius: 4 },
  name: { fontFamily: font.mono, fontSize: 13, fontWeight: "700", flex: 1 },
  conf: { fontFamily: font.mono, fontSize: 12, color: colors.muted },
  time: { fontFamily: font.mono, fontSize: 11, color: colors.muted },
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
export default function HistoryScreen() {
  const { connected, hasSignal, history, emotionHistory } = useSentio();
  const recentHistory = history.slice(-60); // last 60 samples for chart

  return (
    <ScrollView style={styles.root} contentContainerStyle={styles.content}>
      <ConnectionBanner connected={connected} hasSignal={hasSignal} />

      {/* ── EEG Band Charts ── */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>EEG BAND HISTORY  ·  last {recentHistory.length} frames</Text>
        {recentHistory.length === 0 ? (
          <Text style={styles.empty}>No data yet — waiting for EEG signal…</Text>
        ) : (
          <View style={[styles.chartCard, { width: CHART_W + 2 }]}>
            {BAND_META.map(({ key, label, color }) => (
              <View key={key} style={styles.chartRow}>
                <Text style={[styles.chartLabel, { color }]}>{label}</Text>
                <View style={[styles.chartArea, { overflow: "hidden" }]}>
                  <Sparkline band={key} data={recentHistory} color={color} />
                </View>
              </View>
            ))}
          </View>
        )}
      </View>

      {/* ── Emotion Timeline ── */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>EMOTION TIMELINE  ·  last {emotionHistory.length} changes</Text>
        {emotionHistory.length === 0 ? (
          <Text style={styles.empty}>No emotion changes recorded yet…</Text>
        ) : (
          [...emotionHistory].reverse().map((entry, i) => (
            <EmotionPill key={i} {...entry} />
          ))
        )}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  root:    { flex: 1, backgroundColor: colors.bg },
  content: { padding: spacing.md, paddingBottom: 48 },

  section:      { marginBottom: spacing.lg },
  sectionTitle: {
    fontFamily:    font.mono,
    fontSize:      10,
    letterSpacing: 2,
    color:         colors.muted,
    marginBottom:  spacing.sm,
  },
  empty: { color: colors.muted, fontFamily: font.mono, fontSize: 13, paddingVertical: spacing.sm },

  chartCard: {
    backgroundColor: colors.bg2,
    borderWidth:     1,
    borderColor:     colors.border,
    borderRadius:    radius.md,
    padding:         spacing.md,
    gap:             spacing.sm,
  },
  chartRow: { gap: 4 },
  chartLabel: { fontFamily: font.mono, fontSize: 11, marginBottom: 4 },
  chartArea:  { height: CHART_H },
});
