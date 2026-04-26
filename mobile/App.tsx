/**
 * Sentio Mobile — App root  (Ionic React + Capacitor)
 *
 * Screen flow:
 *   1. MuseScanScreen  — BLE scan & connect
 *        → connected / skip   →  ConfigScreen
 *   2. ConfigScreen    — pick pattern, sensitivity, smoothing
 *        → Start Session       →  Monitoring (tabs)
 *   3. Monitoring tabs — Live · History
 *        → STOP ✕              →  MuseScanScreen
 */
import React, { useState, useCallback } from "react";
import { IonApp } from "@ionic/react";

import { SentioProvider }    from "./src/lib/SentioContext";
import { MuseBLEProvider }   from "./src/lib/MuseBLEContext";
import { stopSession }       from "./src/lib/sentioApi";
import MuseScanScreen        from "./src/screens/MuseScanScreen";
import ConfigScreen, { MobileSessionConfig } from "./src/screens/ConfigScreen";
import DashboardScreen       from "./src/screens/DashboardScreen";
import HistoryScreen         from "./src/screens/HistoryScreen";
import { MuseDevice }        from "./src/hooks/useMuseBLE";
import { colors, spacing }   from "./src/theme";

type Screen = "ble-connect" | "config" | "monitoring";

export default function App() {
  const [screen, setScreen] = useState<Screen>("ble-connect");
  const [tab,    setTab   ] = useState<"live" | "history">("live");

  const handleMuseConnected = useCallback((_d: MuseDevice) => setScreen("config"), []);
  const handleSkipBLE       = useCallback(() => setScreen("config"), []);
  const handleStart         = useCallback((_c: MobileSessionConfig) => setScreen("monitoring"), []);

  const handleStop = useCallback(async () => {
    try { await stopSession(); } catch { /* already stopped */ }
    setScreen("ble-connect");
  }, []);

  return (
    <IonApp>
      <MuseBLEProvider>
        <SentioProvider>

          {/* ── Step 1: Bluetooth scan ── */}
          {screen === "ble-connect" && (
            <MuseScanScreen onConnected={handleMuseConnected} onSkip={handleSkipBLE} />
          )}

          {/* ── Step 2: Session config ── */}
          {screen === "config" && (
            <ConfigScreen onStart={handleStart} />
          )}

          {/* ── Step 3: Monitoring (tabs) ── */}
          {screen === "monitoring" && (
            <div style={{ display: "flex", flexDirection: "column", height: "100vh", background: colors.bg }}>
              {/* Top bar */}
              <div style={{
                display: "flex", alignItems: "center", justifyContent: "space-between",
                padding: `${spacing.sm}px ${spacing.md}px`,
                borderBottom: `1px solid ${colors.border}`,
                background: colors.bg,
              }}>
                <span style={{
                  fontFamily: "monospace", fontSize: 13,
                  letterSpacing: 3, color: colors.cyan,
                }}>
                  SENTIO
                </span>
                <button
                  onClick={handleStop}
                  style={{
                    background: "none", border: "none", cursor: "pointer",
                    fontFamily: "monospace", fontSize: 11,
                    color: colors.muted, letterSpacing: 1,
                  }}
                >
                  STOP ✕
                </button>
              </div>

              {/* Tab content */}
              <div style={{ flex: 1, overflow: "auto" }}>
                {tab === "live"    && <DashboardScreen />}
                {tab === "history" && <HistoryScreen />}
              </div>

              {/* Tab bar */}
              <div style={{
                display: "flex",
                borderTop: `1px solid ${colors.border}`,
                background: colors.bg2,
              }}>
                {(["live", "history"] as const).map(t => (
                  <button
                    key={t}
                    onClick={() => setTab(t)}
                    style={{
                      flex: 1, padding: `${spacing.sm}px 0`,
                      background: "none", border: "none", cursor: "pointer",
                      display: "flex", flexDirection: "column",
                      alignItems: "center", gap: 2,
                    }}
                  >
                    <span style={{ fontSize: 20, opacity: tab === t ? 1 : 0.4 }}>
                      {t === "live" ? "🧠" : "📈"}
                    </span>
                    <span style={{
                      fontFamily: "monospace", fontSize: 10, letterSpacing: 1,
                      color: tab === t ? colors.cyan : colors.muted,
                    }}>
                      {t.toUpperCase()}
                    </span>
                  </button>
                ))}
              </div>
            </div>
          )}

        </SentioProvider>
      </MuseBLEProvider>
    </IonApp>
  );
}
