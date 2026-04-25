/**
 * Sentio Mobile — App root
 *
 * Screen flow:
 *   1.  MuseScanScreen  — scan & connect to Muse 2 via phone Bluetooth
 *         → connected              →  ConfigScreen
 *         → "Skip" button          →  ConfigScreen (backend handles BLE)
 *   2.  ConfigScreen    — pick pattern type, sensitivity, smoothing → Start
 *         → Start Session          →  Monitoring tabs
 *   3.  Monitoring tabs — Live · History
 *         → STOP ✕                 →  MuseScanScreen (restart flow)
 */
import React, { useState, useCallback } from "react";
import { TouchableOpacity, Text }           from "react-native";
import { StatusBar }                        from "expo-status-bar";
import { NavigationContainer }              from "@react-navigation/native";
import { createBottomTabNavigator }         from "@react-navigation/bottom-tabs";

import { SentioProvider }                   from "./src/lib/SentioContext";
import { MuseBLEProvider }                  from "./src/lib/MuseBLEContext";
import { stopSession }                      from "./src/lib/sentioApi";
import MuseScanScreen                       from "./src/screens/MuseScanScreen";
import ConfigScreen, { MobileSessionConfig } from "./src/screens/ConfigScreen";
import DashboardScreen                      from "./src/screens/DashboardScreen";
import HistoryScreen                        from "./src/screens/HistoryScreen";
import { MuseDevice }                       from "./src/hooks/useMuseBLE";
import { colors, font, spacing }            from "./src/theme";

// ─── helpers ──────────────────────────────────────────────────────────────────

function TabIcon({ emoji, focused }: { emoji: string; focused: boolean }) {
  return <Text style={{ fontSize: 20, opacity: focused ? 1 : 0.4 }}>{emoji}</Text>;
}

const Tab = createBottomTabNavigator();

// ─── Root component ───────────────────────────────────────────────────────────

type Screen = "ble-connect" | "config" | "monitoring";

export default function App() {
  const [screen, setScreen] = useState<Screen>("ble-connect");

  // ── BLE screen → Config screen ────────────────────────────────────────────
  const handleMuseConnected = useCallback((_device: MuseDevice) => {
    setScreen("config");
  }, []);

  const handleSkipBLE = useCallback(() => {
    setScreen("config");
  }, []);

  // ── Config screen → Monitoring tabs ──────────────────────────────────────
  const handleStart = useCallback((_cfg: MobileSessionConfig) => {
    setScreen("monitoring");
  }, []);

  // ── Monitoring STOP → back to BLE screen ─────────────────────────────────
  const handleStop = useCallback(async () => {
    try { await stopSession(); } catch { /* already stopped */ }
    setScreen("ble-connect");
  }, []);

  return (
    <MuseBLEProvider>
      <SentioProvider>
        <StatusBar style="light" backgroundColor={colors.bg} />

        {/* ── Step 1: Connect Muse 2 via Bluetooth ── */}
        {screen === "ble-connect" && (
          <MuseScanScreen
            onConnected={handleMuseConnected}
            onSkip={handleSkipBLE}
          />
        )}

        {/* ── Step 2: Configure session ── */}
        {screen === "config" && (
          <ConfigScreen onStart={handleStart} />
        )}

        {/* ── Step 3: Live monitoring tabs ── */}
        {screen === "monitoring" && (
          <NavigationContainer>
            <Tab.Navigator
              screenOptions={{
                headerStyle: {
                  backgroundColor: colors.bg,
                  borderBottomWidth: 0,
                  shadowOpacity: 0,
                  elevation: 0,
                },
                headerTintColor:         colors.text,
                headerTitleStyle:        { fontFamily: font.mono, fontSize: 13, letterSpacing: 3 },
                headerRight: () => (
                  <TouchableOpacity
                    onPress={handleStop}
                    style={{ marginRight: spacing.md }}
                    activeOpacity={0.7}
                  >
                    <Text style={{ fontFamily: font.mono, fontSize: 11, color: colors.muted, letterSpacing: 1 }}>
                      STOP ✕
                    </Text>
                  </TouchableOpacity>
                ),
                tabBarStyle:             { backgroundColor: colors.bg2, borderTopColor: colors.border },
                tabBarActiveTintColor:   colors.cyan,
                tabBarInactiveTintColor: colors.muted,
                tabBarLabelStyle:        { fontFamily: font.mono, fontSize: 10, letterSpacing: 1 },
              }}
            >
              <Tab.Screen
                name="Live"
                component={DashboardScreen}
                options={{
                  title:       "SENTIO",
                  tabBarLabel: "LIVE",
                  tabBarIcon:  ({ focused }) => <TabIcon emoji="🧠" focused={focused} />,
                }}
              />
              <Tab.Screen
                name="History"
                component={HistoryScreen}
                options={{
                  title:       "HISTORY",
                  tabBarLabel: "HISTORY",
                  tabBarIcon:  ({ focused }) => <TabIcon emoji="📈" focused={focused} />,
                }}
              />
            </Tab.Navigator>
          </NavigationContainer>
        )}

      </SentioProvider>
    </MuseBLEProvider>
  );
}
