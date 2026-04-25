import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { colors, spacing, radius, font } from "../theme";

interface StatItem {
  label: string;
  value: string | number | null | undefined;
  unit?: string;
  color?: string;
}

export default function StatRow({ items }: { items: StatItem[] }) {
  return (
    <View style={styles.row}>
      {items.map(({ label, value, unit, color }) => (
        <View key={label} style={styles.card}>
          <Text style={styles.label}>{label}</Text>
          <Text style={[styles.value, color ? { color } : {}]}>
            {value !== null && value !== undefined && value !== "" ? `${value}${unit ?? ""}` : "—"}
          </Text>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: "row", gap: spacing.sm },
  card: {
    flex:            1,
    backgroundColor: colors.bg2,
    borderWidth:     1,
    borderColor:     colors.border,
    borderRadius:    radius.md,
    padding:         spacing.sm,
    alignItems:      "center",
  },
  label: { fontFamily: font.mono, fontSize: 9,  color: colors.muted, letterSpacing: 1, marginBottom: 4 },
  value: { fontFamily: font.mono, fontSize: 17, color: colors.text, fontWeight: "700" },
});
