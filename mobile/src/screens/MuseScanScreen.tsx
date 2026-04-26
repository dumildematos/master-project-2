/**
 * MuseScanScreen  (Ionic)
 * -----------------------
 * Phase A — Explain + start scan (Capacitor BLE handles permissions internally)
 * Phase B — Display discovered Muse headsets; tap a card to connect
 * Phase C — Connecting overlay spinner
 */
import React, { useEffect, useState } from "react";
import {
  IonPage, IonContent, IonSpinner, IonButton,
} from "@ionic/react";
import { useMuseBLEContext } from "../lib/MuseBLEContext";
import { MuseDevice } from "../hooks/useMuseBLE";
import { colors, spacing } from "../theme";

interface Props {
  onConnected: (device: MuseDevice) => void;
  onSkip:      () => void;
}

type Phase = "intro" | "scanning" | "connecting" | "error";

// ── Styles ────────────────────────────────────────────────────────────────────
const s = {
  page:   { background: colors.bg, minHeight: "100vh", display: "flex", flexDirection: "column" as const },
  header: {
    textAlign: "center" as const,
    padding: `${spacing.xl + 16}px ${spacing.md}px ${spacing.lg}px`,
    borderBottom: `1px solid ${colors.border}`,
  },
  wordmark: {
    fontFamily: "monospace", fontSize: 26, fontWeight: 800,
    letterSpacing: 6, color: colors.cyan, margin: 0,
  },
  subtitle: {
    fontFamily: "monospace", fontSize: 11, color: colors.muted,
    marginTop: spacing.xs, letterSpacing: 2,
  },

  // Intro / error
  centreWrap: {
    flex: 1, display: "flex", flexDirection: "column" as const,
    alignItems: "center", justifyContent: "center",
    padding: spacing.xl, gap: spacing.md,
    textAlign: "center" as const,
  },
  bigIcon:   { fontSize: 52, lineHeight: 1 },
  title: {
    fontFamily: "monospace", fontSize: 16, fontWeight: 700,
    color: colors.text, margin: 0,
  },
  body: {
    fontFamily: "monospace", fontSize: 12, color: colors.muted,
    lineHeight: 1.7, maxWidth: 320,
  },
  errorBanner: {
    background: "#ff6b6b18", border: `1px solid #ff6b6b44`,
    borderRadius: 12, padding: spacing.sm, width: "100%",
    fontFamily: "monospace", fontSize: 11, color: "#ff6b6b",
  },
  allowBtn: {
    background: colors.cyan, borderRadius: 12, width: "100%",
    border: "none", padding: `${spacing.md}px`, cursor: "pointer",
    fontFamily: "monospace", fontSize: 14, fontWeight: 700,
    color: colors.bg, letterSpacing: 1, marginTop: spacing.sm,
  },

  // Scanning
  statusWrap: { padding: spacing.md },
  statusPill: {
    display: "inline-flex", alignItems: "center", gap: 8,
    background: colors.bg2, border: `1px solid ${colors.cyan}55`,
    borderRadius: 999, padding: `${spacing.sm}px ${spacing.md}px`,
    fontFamily: "monospace", fontSize: 11, color: colors.cyan, letterSpacing: 1,
  },
  list: { padding: `0 ${spacing.md}px`, display: "flex", flexDirection: "column" as const, gap: spacing.sm },
  deviceCard: {
    display: "flex", alignItems: "center", gap: spacing.md,
    background: colors.bg2, border: `1px solid ${colors.cyan}55`,
    borderRadius: 16, padding: spacing.md, cursor: "pointer",
    boxShadow: `0 2px 8px ${colors.cyan}1a`, transition: "opacity .15s",
  },
  signalWrap: { display: "flex", alignItems: "flex-end", gap: 3, width: 24 },
  deviceInfo: { flex: 1 },
  deviceName: {
    fontFamily: "monospace", fontSize: 15, fontWeight: 700, color: colors.text, margin: 0,
  },
  deviceMeta: {
    fontFamily: "monospace", fontSize: 10, color: colors.muted, marginTop: 3,
  },
  connectChip: {
    background: colors.cyan, borderRadius: 999,
    padding: `6px ${spacing.md}px`,
    fontFamily: "monospace", fontSize: 11, fontWeight: 700,
    color: colors.bg, letterSpacing: 1, border: "none", cursor: "pointer",
  },
  emptyWrap: {
    display: "flex", flexDirection: "column" as const,
    alignItems: "center", justifyContent: "center",
    padding: spacing.xl, gap: spacing.md, textAlign: "center" as const,
    flex: 1,
  },
  emptyIcon:  { fontSize: 48, lineHeight: 1 },
  emptyTitle: {
    fontFamily: "monospace", fontSize: 14, fontWeight: 700, color: colors.text, margin: 0,
  },
  emptyHint:  { fontFamily: "monospace", fontSize: 12, color: colors.muted, lineHeight: 1.7 },

  actions: {
    padding: spacing.md, paddingBottom: spacing.xl,
    display: "flex", flexDirection: "column" as const, gap: spacing.sm,
    borderTop: `1px solid ${colors.border}`,
  },
  stopBtn: {
    background: colors.bg2, border: `1px solid ${colors.border}`,
    borderRadius: 12, padding: spacing.md, cursor: "pointer",
    fontFamily: "monospace", fontSize: 13, color: colors.muted, letterSpacing: 1,
  },
  skipBtn:     { textAlign: "center" as const, padding: `${spacing.sm}px 0`, cursor: "pointer" },
  skipBtnText: { fontFamily: "monospace", fontSize: 11, color: colors.muted },
} as const;

// ── Signal bar helpers ────────────────────────────────────────────────────────
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

// ── Component ─────────────────────────────────────────────────────────────────
export default function MuseScanScreen({ onConnected, onSkip }: Props) {
  const {
    bleState, devices, connectedDevice, error,
    scan, stopScan, connect,
  } = useMuseBLEContext();

  const [phase, setPhase] = useState<Phase>("intro");

  useEffect(() => {
    if (bleState === "connected" && connectedDevice) onConnected(connectedDevice);
    if (bleState === "connecting") setPhase("connecting");
    if (bleState === "error")      setPhase("error");
    if (bleState === "scanning")   setPhase("scanning");
  }, [bleState, connectedDevice]); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <IonPage>
      <IonContent style={{ "--background": colors.bg }}>
        <div style={s.page}>

          {/* Header */}
          <div style={s.header}>
            <h1 style={s.wordmark}>SENTIO</h1>
            <p style={s.subtitle}>Connect your Muse 2 headset</p>
          </div>

          {/* ── PHASE A: Intro ── */}
          {phase === "intro" && (
            <div style={s.centreWrap}>
              <span style={s.bigIcon}>📡</span>
              <h2 style={s.title}>Find Your Muse 2</h2>
              <p style={s.body}>
                Sentio will scan for nearby Muse 2 EEG headsets via Bluetooth.
                Your Bluetooth data is never shared or stored.
              </p>
              <button style={s.allowBtn} onClick={scan}>
                Start Scanning
              </button>
              <button style={s.skipBtn} onClick={onSkip}>
                <span style={s.skipBtnText}>Skip — use backend Bluetooth instead</span>
              </button>
            </div>
          )}

          {/* ── PHASE B: Scanning ── */}
          {phase === "scanning" && (
            <div style={{ flex: 1, display: "flex", flexDirection: "column" }}>
              {/* Status pill */}
              <div style={s.statusWrap}>
                <div style={s.statusPill}>
                  <IonSpinner name="dots" style={{ width: 16, height: 16, color: colors.cyan }} />
                  <span>
                    {devices.length === 0
                      ? "Scanning for Muse headsets…"
                      : `${devices.length} headset${devices.length !== 1 ? "s" : ""} found`}
                  </span>
                </div>
              </div>

              {/* Device list or empty state */}
              {devices.length > 0 ? (
                <div style={s.list}>
                  {devices.map(d => (
                    <div
                      key={d.id}
                      style={s.deviceCard}
                      onClick={() => connect(d)}
                    >
                      {/* Signal bars */}
                      <div style={s.signalWrap}>
                        {[0, 1, 2].map(i => (
                          <div
                            key={i}
                            style={{
                              width: 5, height: 6 + i * 5, borderRadius: 2,
                              backgroundColor: signalLevel(d.rssi) > i
                                ? rssiColor(d.rssi) : colors.border,
                            }}
                          />
                        ))}
                      </div>

                      <div style={s.deviceInfo}>
                        <p style={s.deviceName}>{d.name}</p>
                        <p style={s.deviceMeta}>{d.id} · {d.rssi} dBm</p>
                      </div>

                      <button style={s.connectChip} onClick={e => { e.stopPropagation(); connect(d); }}>
                        CONNECT
                      </button>
                    </div>
                  ))}
                </div>
              ) : (
                <div style={s.emptyWrap}>
                  <span style={s.emptyIcon}>🎧</span>
                  <h3 style={s.emptyTitle}>No headsets detected</h3>
                  <p style={s.emptyHint}>
                    Power on your Muse 2 and hold the button for 2 s until you hear a beep.
                  </p>
                </div>
              )}

              <div style={s.actions}>
                <button style={s.stopBtn} onClick={stopScan}>Stop Scanning</button>
                <button style={s.skipBtn} onClick={onSkip}>
                  <span style={s.skipBtnText}>Skip — use backend Bluetooth instead</span>
                </button>
              </div>
            </div>
          )}

          {/* ── PHASE C: Connecting ── */}
          {phase === "connecting" && (
            <div style={{ ...s.centreWrap, gap: spacing.md }}>
              <IonSpinner name="circular" style={{ width: 48, height: 48, color: colors.cyan }} />
              <h2 style={{ ...s.title, letterSpacing: 2 }}>Connecting to Muse 2…</h2>
              <p style={{ fontFamily: "monospace", fontSize: 11, color: colors.muted, margin: 0 }}>
                Subscribing to EEG channels
              </p>
            </div>
          )}

          {/* ── ERROR state ── */}
          {phase === "error" && (
            <div style={s.centreWrap}>
              <span style={s.bigIcon}>⚠️</span>
              <h2 style={s.title}>Connection Error</h2>
              <p style={s.body}>{error ?? "An unexpected error occurred."}</p>
              <button style={s.allowBtn} onClick={() => setPhase("intro")}>
                Try Again
              </button>
              <button style={s.skipBtn} onClick={onSkip}>
                <span style={s.skipBtnText}>Skip — use backend Bluetooth instead</span>
              </button>
            </div>
          )}

        </div>
      </IonContent>
    </IonPage>
  );
}
