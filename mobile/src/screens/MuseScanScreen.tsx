/**
 * MuseScanScreen
 * --------------
 * First screen the user sees — scan for Muse 2 headsets via Bluetooth
 * and connect before starting a session.
 *
 * Props:
 *   onConnected — called after a successful GATT connection + EEG subscription
 *   onSkip      — proceed without a headset (uses backend BLE instead)
 */
import React, { useEffect } from "react";
import {
  View, Text, TouchableOpacity, FlatList,
  StyleSheet, ActivityIndicator, Platform,
} from "react-native";
import { useMuseBLEContext } from "../lib/MuseBLEContext";
import { MuseDevice } from "../hooks/useMuseBLE";
import { colors, spacing, radius, font } from "../theme";

interface Props {
  onConnected: (device: MuseDevice) => void;
  onSkip:      () => void;
}

export default function MuseScanScreen({ onConnected, onSkip }: Props) {
  const {
    bleState, devices, connectedDevice, error,
    scan, stopScan, connect,
  } = useMuseBLEContext();

  // Start scanning immediately on mount
  useEffect(() => {
    scan();
    return () => stopScan();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  // Move to ConfigScreen as soon as a device connects
  useEffect(() => {
    if (bleState === "connected" && connectedDevice) {
      onConnected(connectedDevice);
    }
  }, [bleState, connectedDevice]); // eslint-disable-line react-hooks/exhaustive-deps

  const isScanning   = bleState === "scanning";
  const isConnecting = bleState === "connecting";
  const isBusy       = isScanning || isConnecting;
  const isUnavailable = bleState === "unavailable";

  return (
    <View style={styles.root}>

      {/* ── Header ── */}
      <View style={styles.header}>
        <Text style={styles.wordmark}>SENTIO</Text>
        <Text style={styles.subtitle}>Connect your Muse 2 headset</Text>
      </View>

      {/* ── Status pill ── */}
      <View style={styles.statusWrap}>
        <View style={[
          styles.statusPill,
          isScanning   && styles.statusPillScanning,
          isConnecting && styles.statusPillConnecting,
          bleState === "error" && styles.statusPillError,
        ]}>
          {isBusy && (
            <ActivityIndicator
              color={isConnecting ? colors.magenta : colors.cyan}
              size="small"
              style={{ marginRight: 8 }}
            />
          )}
          <Text style={[
            styles.statusText,
            isConnecting && { color: colors.magenta },
            bleState === "error" && { color: "#ff6b6b" },
          ]}>
            {isScanning   ? "Scanning for Muse headsets…"
           : isConnecting ? "Connecting…"
           : bleState === "error" ? (error ?? "Bluetooth error")
           : isUnavailable ? (Platform.OS === "web" ? "Bluetooth unavailable on web" : "Bluetooth unavailable")
           : devices.length === 0 ? "No Muse headsets found nearby"
           : `${devices.length} headset${devices.length !== 1 ? "s" : ""} found`}
          </Text>
        </View>
      </View>

      {/* ── Device list ── */}
      {devices.length > 0 ? (
        <FlatList
          data={devices}
          keyExtractor={d => d.id}
          style={styles.list}
          contentContainerStyle={styles.listContent}
          renderItem={({ item: d }) => (
            <TouchableOpacity
              style={[styles.deviceCard, isBusy && styles.deviceCardDisabled]}
              onPress={() => { if (!isBusy) connect(d); }}
              activeOpacity={0.75}
              disabled={isBusy}
            >
              {/* Signal strength indicator */}
              <View style={styles.signalWrap}>
                {[0, 1, 2].map(i => (
                  <View
                    key={i}
                    style={[
                      styles.signalBar,
                      { height: 6 + i * 5 },
                      signalLevel(d.rssi) > i
                        ? { backgroundColor: rssiColor(d.rssi) }
                        : { backgroundColor: colors.border },
                    ]}
                  />
                ))}
              </View>

              <View style={styles.deviceInfo}>
                <Text style={styles.deviceName}>{d.name}</Text>
                <Text style={styles.deviceMeta}>{d.id}  ·  {d.rssi} dBm</Text>
              </View>

              <View style={styles.connectChip}>
                <Text style={styles.connectChipText}>TAP TO CONNECT</Text>
              </View>
            </TouchableOpacity>
          )}
        />
      ) : (
        /* ── Empty / hint state ── */
        <View style={styles.emptyWrap}>
          <Text style={styles.emptyIcon}>🎧</Text>
          <Text style={styles.emptyTitle}>No headsets detected</Text>
          <Text style={styles.emptyHint}>
            Power on your Muse 2 and hold the button for 2 seconds until you hear a beep and the LED pulses.
          </Text>
        </View>
      )}

      {/* ── Action buttons ── */}
      <View style={styles.actions}>
        {!isScanning && !isUnavailable && (
          <TouchableOpacity
            style={[styles.scanBtn, isConnecting && styles.scanBtnDisabled]}
            onPress={scan}
            disabled={isConnecting}
            activeOpacity={0.8}
          >
            <Text style={styles.scanBtnText}>
              {devices.length > 0 ? "🔄  Scan Again" : "🔍  Start Scan"}
            </Text>
          </TouchableOpacity>
        )}

        {isScanning && (
          <TouchableOpacity style={styles.stopBtn} onPress={stopScan} activeOpacity={0.8}>
            <Text style={styles.stopBtnText}>Stop Scanning</Text>
          </TouchableOpacity>
        )}

        <TouchableOpacity style={styles.skipBtn} onPress={onSkip} activeOpacity={0.7}>
          <Text style={styles.skipBtnText}>
            Skip — use backend Bluetooth instead
          </Text>
        </TouchableOpacity>
      </View>

    </View>
  );
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function rssiColor(rssi: number): string {
  if (rssi >= -60) return "#4ade80";
  if (rssi >= -75) return colors.cyan;
  return colors.muted;
}

function signalLevel(rssi: number): number {
  if (rssi >= -60) return 3;
  if (rssi >= -75) return 2;
  if (rssi >= -90) return 1;
  return 0;
}

// ── Styles ────────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },

  header: {
    alignItems:   "center",
    paddingTop:   spacing.xl + 16,
    paddingBottom: spacing.lg,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  wordmark: {
    fontFamily:    font.mono,
    fontSize:      26,
    fontWeight:    "800",
    letterSpacing: 6,
    color:         colors.cyan,
  },
  subtitle: {
    fontFamily:    font.mono,
    fontSize:      11,
    color:         colors.muted,
    marginTop:     spacing.xs,
    letterSpacing: 2,
  },

  statusWrap: { padding: spacing.md },
  statusPill: {
    flexDirection:  "row",
    alignItems:     "center",
    backgroundColor: colors.bg2,
    borderWidth:    1,
    borderColor:    colors.border,
    borderRadius:   radius.full,
    paddingHorizontal: spacing.md,
    paddingVertical:   spacing.sm,
    alignSelf:      "center",
  },
  statusPillScanning:  { borderColor: colors.cyan  + "66" },
  statusPillConnecting:{ borderColor: colors.magenta + "66" },
  statusPillError:     { borderColor: "#ff6b6b66" },
  statusText: {
    fontFamily: font.mono,
    fontSize:   11,
    color:      colors.cyan,
    letterSpacing: 1,
  },

  list:        { flex: 1 },
  listContent: { padding: spacing.md, gap: spacing.sm },

  deviceCard: {
    flexDirection:   "row",
    alignItems:      "center",
    backgroundColor: colors.bg2,
    borderWidth:     1,
    borderColor:     colors.border,
    borderRadius:    radius.lg,
    padding:         spacing.md,
    gap:             spacing.md,
  },
  deviceCardDisabled: { opacity: 0.5 },

  signalWrap: {
    flexDirection: "row",
    alignItems:    "flex-end",
    gap:           3,
    width:         24,
  },
  signalBar: { width: 5, borderRadius: 2 },

  deviceInfo: { flex: 1 },
  deviceName: { fontFamily: font.mono, fontSize: 15, fontWeight: "700", color: colors.text },
  deviceMeta: { fontFamily: font.mono, fontSize: 10, color: colors.muted, marginTop: 3 },

  connectChip: {
    backgroundColor: colors.cyan + "18",
    borderWidth:     1,
    borderColor:     colors.cyan + "44",
    borderRadius:    radius.full,
    paddingHorizontal: spacing.sm,
    paddingVertical:   4,
  },
  connectChipText: { fontFamily: font.mono, fontSize: 9, color: colors.cyan, letterSpacing: 1 },

  emptyWrap: {
    flex:        1,
    alignItems:  "center",
    justifyContent: "center",
    padding:     spacing.xl,
    gap:         spacing.md,
  },
  emptyIcon:  { fontSize: 52 },
  emptyTitle: { fontFamily: font.mono, fontSize: 14, fontWeight: "700", color: colors.text },
  emptyHint:  {
    fontFamily: font.mono,
    fontSize:   12,
    color:      colors.muted,
    textAlign:  "center",
    lineHeight: 20,
  },

  actions: {
    padding: spacing.md,
    paddingBottom: spacing.xl,
    gap:     spacing.sm,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
  scanBtn: {
    backgroundColor: colors.cyan,
    borderRadius:    radius.md,
    padding:         spacing.md,
    alignItems:      "center",
  },
  scanBtnDisabled: { opacity: 0.5 },
  scanBtnText: {
    fontFamily: font.mono,
    fontSize:   13,
    fontWeight: "700",
    color:      colors.bg,
    letterSpacing: 1,
  },
  stopBtn: {
    backgroundColor: colors.bg2,
    borderWidth:     1,
    borderColor:     colors.border,
    borderRadius:    radius.md,
    padding:         spacing.md,
    alignItems:      "center",
  },
  stopBtnText: { fontFamily: font.mono, fontSize: 13, color: colors.muted, letterSpacing: 1 },

  skipBtn: {
    alignItems:  "center",
    paddingVertical: spacing.sm,
  },
  skipBtnText: { fontFamily: font.mono, fontSize: 11, color: colors.muted },
});
