import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { colors, spacing, radius, font } from "../theme";

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
    <View style={styles.container}>
      {BANDS.map(({ key, label, color, desc }) => {
        const value = bands[key] ?? 0;
        return (
          <View key={key} style={styles.row}>
            <View style={styles.labelBlock}>
              <Text style={styles.label}>{label}</Text>
              {showDesc && <Text style={styles.desc}>{desc}</Text>}
            </View>
            <View style={styles.track}>
              <View
                style={[
                  styles.fill,
                  { width: `${Math.min(100, Math.round(value * 100))}%`, backgroundColor: color },
                ]}
              />
            </View>
            <Text style={styles.pct}>{(value * 100).toFixed(0)}%</Text>
          </View>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: spacing.sm },
  row:       { flexDirection: "row", alignItems: "center", gap: spacing.sm },
  labelBlock:{ width: 90 },
  label:     { fontFamily: font.mono, fontSize: 12, color: colors.text },
  desc:      { fontFamily: font.mono, fontSize: 9,  color: colors.muted, marginTop: 1 },
  track: {
    flex:         1,
    height:       7,
    backgroundColor: colors.border,
    borderRadius: radius.full,
    overflow:     "hidden",
  },
  fill:  { height: "100%", borderRadius: radius.full },
  pct:   { fontFamily: font.mono, fontSize: 12, color: colors.muted, width: 36, textAlign: "right" },
});
