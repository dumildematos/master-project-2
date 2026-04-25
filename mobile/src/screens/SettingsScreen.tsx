/**
 * SettingsScreen
 * --------------
 * - Set backend URL (stored as "sentioApiUrl" — same key as the web frontend)
 * - View live session status and stop an active session
 * - Demo Mode: inject manual EEG frames without a headset (same presets as web)
 * - Start a real session (requires Muse 2 headset connected to backend)
 */
import React, { useEffect, useState, useCallback } from "react";
import {
  View, Text, TextInput, TouchableOpacity, StyleSheet, ScrollView,
  KeyboardAvoidingView, Platform, Alert, ActivityIndicator,
} from "react-native";
import { getStoredApiUrl, saveApiUrl } from "../lib/runtimeConfig";
import {
  getSessionStatus, sendManualOverride, stopSession,
  SessionStatus, EmotionKey, EMOTION_PRESETS,
} from "../lib/sentioApi";
import { useSentio } from "../lib/SentioContext";
import { colors, emotionColor, emotionLabel, spacing, radius, font } from "../theme";

export default function SettingsScreen() {
  const { connected, reconnect } = useSentio();

  const [apiUrl,  setApiUrl ] = useState("");
  const [saving,  setSaving ] = useState(false);

  const [sessionStatus,  setSessionStatus ] = useState<SessionStatus | null>(null);
  const [statusLoading,  setStatusLoading ] = useState(false);

  const [activeEmotion,   setActiveEmotion  ] = useState<EmotionKey | null>(null);
  const [overrideLoading, setOverrideLoading] = useState(false);

  // Load stored URL on mount
  useEffect(() => {
    getStoredApiUrl().then(setApiUrl);
  }, []);

  // Poll session status every 3 s
  const refreshStatus = useCallback(async () => {
    if (!connected) { setSessionStatus(null); return; }
    setStatusLoading(true);
    try {
      setSessionStatus(await getSessionStatus());
    } catch {
      setSessionStatus(null);
    } finally {
      setStatusLoading(false);
    }
  }, [connected]);

  useEffect(() => {
    refreshStatus();
    const id = setInterval(refreshStatus, 3000);
    return () => clearInterval(id);
  }, [refreshStatus]);

  // Save URL and reconnect WebSocket
  async function handleSave() {
    const trimmed = apiUrl.trim();
    if (!trimmed) { Alert.alert("Validation", "URL cannot be empty."); return; }
    if (!/^https?:\/\//.test(trimmed)) {
      Alert.alert("Validation", "URL must start with http:// or https://");
      return;
    }
    setSaving(true);
    await saveApiUrl(trimmed);
    await reconnect();
    setSaving(false);
    Alert.alert("Saved", "Reconnecting to backend…");
  }

  // Inject a manual override frame
  async function handleOverride(emotion: EmotionKey) {
    setOverrideLoading(true);
    setActiveEmotion(emotion);
    try {
      await sendManualOverride(emotion);
    } catch (e: any) {
      Alert.alert("Override failed", e?.message ?? "Could not reach backend.");
      setActiveEmotion(null);
    } finally {
      setOverrideLoading(false);
    }
  }

  async function handleStop() {
    try {
      await stopSession();
      setActiveEmotion(null);
      await refreshStatus();
    } catch (e: any) {
      Alert.alert("Stop failed", e?.message ?? "Could not reach backend.");
    }
  }

  const stateColor = (s?: string) => {
    if (s === "running")    return colors.cyan;
    if (s === "connecting") return colors.amber;
    return colors.muted;
  };

  const EMOTIONS = Object.keys(EMOTION_PRESETS) as EmotionKey[];

  return (
    <KeyboardAvoidingView
      style={{ flex: 1, backgroundColor: colors.bg }}
      behavior={Platform.OS === "ios" ? "padding" : undefined}
    >
      <ScrollView style={styles.root} contentContainerStyle={styles.content}>

        {/* ── WS connection indicator ── */}
        <View style={styles.statusRow}>
          <View style={[styles.dot, { backgroundColor: connected ? colors.cyan : colors.muted }]} />
          <Text style={styles.statusText}>
            {connected ? "WebSocket connected" : "Not connected"}
          </Text>
        </View>

        {/* ── Backend URL ── */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>BACKEND URL</Text>
          <Text style={styles.fieldDesc}>
            Enter the full API URL — same value as the web dashboard's backend setting.{"\n"}
            e.g. <Text style={styles.mono}>http://192.168.1.42:8000</Text>
          </Text>
          <TextInput
            style={styles.input}
            value={apiUrl}
            onChangeText={setApiUrl}
            placeholder="http://127.0.0.1:8000"
            placeholderTextColor={colors.muted}
            autoCapitalize="none"
            autoCorrect={false}
            keyboardType="url"
            returnKeyType="done"
            onSubmitEditing={handleSave}
          />
          <TouchableOpacity
            style={[styles.button, saving && styles.buttonDisabled]}
            onPress={handleSave}
            disabled={saving}
            activeOpacity={0.75}
          >
            <Text style={styles.buttonText}>{saving ? "Connecting…" : "Save & Reconnect"}</Text>
          </TouchableOpacity>
        </View>

        {/* ── Session status ── */}
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>SESSION STATUS</Text>
            {statusLoading && <ActivityIndicator size="small" color={colors.muted} />}
          </View>
          <View style={styles.card}>
            {sessionStatus ? (
              <>
                <Row
                  label="State"
                  value={sessionStatus.state.toUpperCase()}
                  valueColor={stateColor(sessionStatus.state)}
                />
                <Row
                  label="Session ID"
                  value={sessionStatus.session_id
                    ? sessionStatus.session_id.slice(0, 8) + "…"
                    : "—"}
                />
                <Row label="Emotions logged" value={String(sessionStatus.emotion_history_length)} />
              </>
            ) : (
              <Text style={styles.emptyText}>
                {connected ? "Fetching status…" : "Connect to backend first"}
              </Text>
            )}
            {sessionStatus?.state === "running" && (
              <TouchableOpacity style={styles.stopBtn} onPress={handleStop} activeOpacity={0.75}>
                <Text style={styles.stopBtnText}>Stop Session</Text>
              </TouchableOpacity>
            )}
          </View>
        </View>

        {/* ── Demo Mode ── */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>DEMO MODE</Text>
          <Text style={styles.fieldDesc}>
            No headset? Inject a synthetic EEG frame into the stream — uses the same
            presets as the web dashboard Manual Mode. All clients (this app, web
            dashboard, Arduino) receive it.
          </Text>
          <View style={styles.emotionGrid}>
            {EMOTIONS.map((em) => {
              const col      = emotionColor[em.toLowerCase()] ?? colors.muted;
              const isActive = activeEmotion === em;
              return (
                <TouchableOpacity
                  key={em}
                  style={[
                    styles.emotionBtn,
                    { borderColor: col + (isActive ? "ff" : "44") },
                    isActive && { backgroundColor: col + "1a" },
                  ]}
                  onPress={() => handleOverride(em)}
                  disabled={overrideLoading}
                  activeOpacity={0.7}
                >
                  <Text style={[styles.emotionBtnText, { color: isActive ? col : colors.muted }]}>
                    {emotionLabel[em.toLowerCase()] ?? em}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </View>
          {activeEmotion && (
            <Text style={styles.activeHint}>
              Injecting{" "}
              <Text style={{ color: emotionColor[activeEmotion.toLowerCase()] ?? colors.cyan }}>
                {emotionLabel[activeEmotion.toLowerCase()] ?? activeEmotion}
              </Text>{" "}
              — tap another to switch
            </Text>
          )}
        </View>

        {/* ── About ── */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>ABOUT</Text>
          <View style={styles.card}>
            <Row label="App"      value="Sentio Mobile" />
            <Row label="Version"  value="1.0.0" />
            <Row label="WS path"  value="/ws/brain-stream" />
            <Row label="AI model" value="claude-haiku-4-5" />
            <Row label="SDK"      value="Expo 54 · RN 0.81" />
          </View>
        </View>

      </ScrollView>
    </KeyboardAvoidingView>
  );
}

function Row({ label, value, valueColor }: { label: string; value: string; valueColor?: string }) {
  return (
    <View style={rowStyles.row}>
      <Text style={rowStyles.label}>{label}</Text>
      <Text style={[rowStyles.value, valueColor ? { color: valueColor } : {}]}>{value}</Text>
    </View>
  );
}

const rowStyles = StyleSheet.create({
  row:   { flexDirection: "row", justifyContent: "space-between", paddingVertical: 5 },
  label: { fontFamily: font.mono, fontSize: 12, color: colors.muted },
  value: { fontFamily: font.mono, fontSize: 12, color: colors.text },
});

const styles = StyleSheet.create({
  root:    { flex: 1 },
  content: { padding: spacing.md, paddingBottom: 48 },

  statusRow:  { flexDirection: "row", alignItems: "center", gap: 8, marginBottom: spacing.lg },
  dot:        { width: 10, height: 10, borderRadius: 5 },
  statusText: { fontFamily: font.mono, fontSize: 13, color: colors.muted },

  section:       { marginBottom: spacing.lg },
  sectionHeader: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", marginBottom: spacing.sm },
  sectionTitle:  { fontFamily: font.mono, fontSize: 10, letterSpacing: 2, color: colors.muted, marginBottom: spacing.sm },

  fieldDesc: { fontSize: 12, color: colors.muted, lineHeight: 18, marginBottom: spacing.sm },
  mono:      { fontFamily: font.mono, color: colors.cyan },

  input: {
    backgroundColor: colors.bg2,
    borderWidth:     1,
    borderColor:     colors.border,
    borderRadius:    radius.md,
    padding:         spacing.sm,
    color:           colors.text,
    fontFamily:      font.mono,
    fontSize:        14,
    marginBottom:    spacing.xs,
  },

  button: {
    backgroundColor: colors.cyan,
    borderRadius:    radius.md,
    padding:         spacing.md,
    alignItems:      "center",
    marginTop:       spacing.sm,
  },
  buttonDisabled: { opacity: 0.5 },
  buttonText: { fontFamily: font.mono, fontSize: 13, fontWeight: "700", color: colors.bg, letterSpacing: 1 },

  card: {
    backgroundColor: colors.bg2,
    borderWidth:     1,
    borderColor:     colors.border,
    borderRadius:    radius.md,
    padding:         spacing.md,
    gap:             2,
  },
  emptyText: { fontFamily: font.mono, fontSize: 12, color: colors.muted, textAlign: "center", paddingVertical: spacing.sm },

  stopBtn: {
    marginTop:    spacing.sm,
    borderWidth:  1,
    borderColor:  "#D00000" + "66",
    borderRadius: radius.md,
    padding:      spacing.sm,
    alignItems:   "center",
  },
  stopBtnText: { fontFamily: font.mono, fontSize: 12, color: "#D00000" },

  emotionGrid: { flexDirection: "row", flexWrap: "wrap", gap: spacing.sm },
  emotionBtn: {
    borderWidth:       1,
    borderRadius:      radius.md,
    paddingVertical:   spacing.sm,
    paddingHorizontal: spacing.md,
    backgroundColor:   colors.bg2,
  },
  emotionBtnText: { fontFamily: font.mono, fontSize: 13, fontWeight: "700" },
  activeHint: { marginTop: spacing.sm, fontSize: 12, color: colors.muted, fontFamily: font.mono },
});
