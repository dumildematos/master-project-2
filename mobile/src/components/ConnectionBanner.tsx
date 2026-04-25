import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { colors, spacing, radius, font } from "../theme";

interface Props {
  connected: boolean;
  hasSignal: boolean;
}

export default function ConnectionBanner({ connected, hasSignal }: Props) {
  if (connected && hasSignal) return null;

  const isWaiting = connected && !hasSignal;

  return (
    <View style={[styles.banner, isWaiting && styles.bannerWaiting]}>
      <View style={[styles.dot, { backgroundColor: isWaiting ? colors.amber : colors.muted }]} />
      <View style={{ flex: 1 }}>
        <Text style={styles.text}>
          {!connected
            ? "Not connected — check backend address in Settings"
            : "Connected · no EEG stream active"}
        </Text>
        {isWaiting && (
          <Text style={styles.hint}>
            Go to Settings → Demo Mode to inject a test signal, or start a session from the web dashboard.
          </Text>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  banner: {
    flexDirection:   "row",
    alignItems:      "flex-start",
    gap:             8,
    backgroundColor: colors.bg2,
    borderWidth:     1,
    borderColor:     colors.border,
    borderRadius:    radius.md,
    padding:         spacing.sm,
    marginBottom:    spacing.md,
  },
  bannerWaiting: { borderColor: colors.amber + "44" },
  dot:   { width: 8, height: 8, borderRadius: 4, marginTop: 3 },
  text:  { color: colors.text, fontSize: 12, fontFamily: font.mono },
  hint:  { color: colors.muted, fontSize: 11, fontFamily: font.mono, marginTop: 4, lineHeight: 16 },
});
