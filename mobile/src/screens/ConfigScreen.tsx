/**
 * ConfigScreen
 * ------------
 * Initial full-screen page — mirrors web frontend's ConfigurationScreen.
 *
 * User picks:
 *   - Pattern type (organic · geometric · fluid · textile)
 *   - Signal Sensitivity (slider 0–100)
 *   - State Smoothing (slider 0–100)
 *
 * Bottom-right floating gear button opens a modal to set:
 *   - Backend API URL
 *   - Muse 2 MAC address
 *
 * "Start Session" calls POST /api/session/start and invokes onStart().
 */
import React, { useEffect, useState } from "react";
import {
  View, Text, TouchableOpacity, StyleSheet, ScrollView,
  Modal, TextInput, KeyboardAvoidingView, Platform,
  ActivityIndicator, Alert,
} from "react-native";
import { getStoredApiUrl, saveApiUrl } from "../lib/runtimeConfig";
import { startSession } from "../lib/sentioApi";
import { useMuseBLEContext } from "../lib/MuseBLEContext";
import { colors, spacing, radius, font } from "../theme";

// ---------------------------------------------------------------------------
// Pattern type options (same as web frontend)
// ---------------------------------------------------------------------------
const PATTERNS = [
  { id: "organic",    label: "Organic",    desc: "Flowing natural forms" },
  { id: "geometric",  label: "Geometric",  desc: "Structured symmetry"   },
  { id: "fluid",      label: "Fluid",      desc: "Liquid motion patterns" },
  { id: "textile",    label: "Textile",    desc: "Woven fabric inspired"  },
] as const;

type PatternId = typeof PATTERNS[number]["id"];

// ---------------------------------------------------------------------------
// Pattern preview (SVG-inspired, done with React Native Views)
// ---------------------------------------------------------------------------
function PatternPreview({ type, active }: { type: PatternId; active: boolean }) {
  const col = active ? colors.cyan : colors.muted;
  const bg  = active ? colors.cyan + "18" : colors.bg;
  return (
    <View style={[preview.box, { backgroundColor: bg, borderColor: active ? colors.cyan + "66" : colors.border }]}>
      {type === "organic" && (
        <>
          <View style={[preview.circle, { width: 36, height: 36, borderColor: col, left: 8, top: 6, opacity: 0.6 }]} />
          <View style={[preview.circle, { width: 24, height: 24, borderColor: col, left: 24, top: 12, opacity: 0.4 }]} />
        </>
      )}
      {type === "geometric" && (
        <>
          <View style={[preview.square, { borderColor: col, opacity: 0.6, transform: [{ rotate: "15deg" }] }]} />
          <View style={[preview.square, { borderColor: col, opacity: 0.35, width: 18, height: 18, transform: [{ rotate: "38deg" }] }]} />
        </>
      )}
      {type === "fluid" && (
        <View style={[preview.line, { borderColor: col, opacity: 0.65 }]} />
      )}
      {type === "textile" && (
        <View style={preview.grid}>
          {[0,1,2].map(i => (
            <View key={i} style={[preview.gridLine, { borderColor: col, opacity: 0.35, marginRight: 8 }]} />
          ))}
        </View>
      )}
    </View>
  );
}

const preview = StyleSheet.create({
  box:    { width: "100%", height: 52, borderWidth: 1, borderRadius: radius.sm, overflow: "hidden", alignItems: "center", justifyContent: "center", marginBottom: spacing.xs },
  circle: { position: "absolute", borderWidth: 1, borderRadius: 100 },
  square: { width: 24, height: 24, borderWidth: 1 },
  line:   { width: "60%", height: 0, borderBottomWidth: 1.5, borderStyle: "solid", transform: [{ translateY: -6 }] },
  grid:   { flexDirection: "row", alignItems: "center" },
  gridLine: { width: 1, height: 28, borderLeftWidth: 1 },
});

// ---------------------------------------------------------------------------
// Slider (native Slider from @react-native-community/slider is optional —
// we build a simple touch-based bar slider to avoid extra dependencies)
// ---------------------------------------------------------------------------
function SimpleSlider({ value, onChange, label, leftLabel, rightLabel }: {
  value: number;
  onChange: (v: number) => void;
  label: string;
  leftLabel?: string;
  rightLabel?: string;
}) {
  return (
    <View style={slider.wrap}>
      <View style={slider.header}>
        <Text style={slider.label}>{label}</Text>
        <Text style={slider.pct}>{value}%</Text>
      </View>
      <View style={slider.track}
        onStartShouldSetResponder={() => true}
        onResponderGrant={(e) => {
          const x = e.nativeEvent.locationX;
          e.target.measure((_fx, _fy, width) => {
            onChange(Math.round(Math.min(100, Math.max(0, (x / width) * 100))));
          });
        }}
        onResponderMove={(e) => {
          const x = e.nativeEvent.locationX;
          e.target.measure((_fx, _fy, width) => {
            onChange(Math.round(Math.min(100, Math.max(0, (x / width) * 100))));
          });
        }}
      >
        <View style={[slider.fill, { width: `${value}%` }]} />
        <View style={[slider.thumb, { left: `${value}%` as any }]} />
      </View>
      {(leftLabel || rightLabel) && (
        <View style={slider.labels}>
          <Text style={slider.sideLabel}>{leftLabel}</Text>
          <Text style={slider.sideLabel}>{rightLabel}</Text>
        </View>
      )}
    </View>
  );
}

const slider = StyleSheet.create({
  wrap:      { marginBottom: spacing.md },
  header:    { flexDirection: "row", justifyContent: "space-between", marginBottom: 6 },
  label:     { fontFamily: font.mono, fontSize: 11, color: colors.muted },
  pct:       { fontFamily: font.mono, fontSize: 11, color: colors.cyan },
  track: {
    height:          6,
    backgroundColor: colors.border,
    borderRadius:    radius.full,
    overflow:        "visible",
    position:        "relative",
  },
  fill: {
    position:        "absolute",
    left:            0,
    top:             0,
    height:          6,
    backgroundColor: colors.cyan,
    borderRadius:    radius.full,
  },
  thumb: {
    position:         "absolute",
    top:              -5,
    width:            16,
    height:           16,
    borderRadius:     8,
    backgroundColor:  colors.cyan,
    transform:        [{ translateX: -8 }],
  },
  labels:    { flexDirection: "row", justifyContent: "space-between", marginTop: 4 },
  sideLabel: { fontFamily: font.mono, fontSize: 9, color: colors.muted },
});

// ---------------------------------------------------------------------------
// Device settings modal (API URL + MAC address)
// ---------------------------------------------------------------------------
function DeviceModal({ visible, onClose }: { visible: boolean; onClose: () => void }) {
  const [url, setUrl] = useState("");

  useEffect(() => {
    if (visible) {
      getStoredApiUrl().then(setUrl);
    }
  }, [visible]);

  async function save() {
    if (url.trim() && !/^https?:\/\//.test(url.trim())) {
      Alert.alert("Invalid URL", "URL must start with http:// or https://");
      return;
    }
    if (url.trim()) await saveApiUrl(url.trim());
    onClose();
  }

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <KeyboardAvoidingView
        style={modal.overlay}
        behavior={Platform.OS === "ios" ? "padding" : undefined}
      >
        <TouchableOpacity style={modal.backdrop} activeOpacity={1} onPress={onClose} />
        <View style={modal.sheet}>
          <View style={modal.handle} />
          <Text style={modal.title}>Backend Settings</Text>

          <Text style={modal.fieldLabel}>API URL</Text>
          <TextInput
            style={modal.input}
            value={url}
            onChangeText={setUrl}
            placeholder="http://192.168.1.42:8000"
            placeholderTextColor={colors.muted}
            autoCapitalize="none"
            autoCorrect={false}
            keyboardType="url"
          />
          <Text style={modal.hint}>Address of the Sentio backend server.</Text>

          <TouchableOpacity style={modal.saveBtn} onPress={save} activeOpacity={0.8}>
            <Text style={modal.saveBtnText}>Save</Text>
          </TouchableOpacity>
          <TouchableOpacity style={modal.cancelBtn} onPress={onClose} activeOpacity={0.7}>
            <Text style={modal.cancelBtnText}>Cancel</Text>
          </TouchableOpacity>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

const modal = StyleSheet.create({
  overlay:    { flex: 1, justifyContent: "flex-end" },
  backdrop:   { ...StyleSheet.absoluteFillObject, backgroundColor: "#00000088" },
  sheet: {
    backgroundColor: colors.bg2,
    borderTopLeftRadius:  20,
    borderTopRightRadius: 20,
    padding:    spacing.lg,
    paddingBottom: 40,
    borderWidth: 1,
    borderBottomWidth: 0,
    borderColor: colors.border,
  },
  handle: {
    alignSelf:       "center",
    width:           40,
    height:          4,
    borderRadius:    2,
    backgroundColor: colors.border,
    marginBottom:    spacing.lg,
  },
  title:      { fontFamily: font.mono, fontSize: 14, fontWeight: "700", color: colors.text, marginBottom: spacing.md, letterSpacing: 2 },
  fieldLabel: { fontFamily: font.mono, fontSize: 10, color: colors.muted, letterSpacing: 2, marginBottom: 6 },
  input: {
    backgroundColor: colors.bg,
    borderWidth:     1,
    borderColor:     colors.border,
    borderRadius:    radius.md,
    padding:         spacing.sm,
    color:           colors.text,
    fontFamily:      font.mono,
    fontSize:        14,
    marginBottom:    4,
  },
  hint:       { fontFamily: font.mono, fontSize: 10, color: colors.muted, marginBottom: 4 },
  saveBtn:    { backgroundColor: colors.cyan, borderRadius: radius.md, padding: spacing.md, alignItems: "center", marginTop: spacing.lg },
  saveBtnText:{ fontFamily: font.mono, fontSize: 13, fontWeight: "700", color: colors.bg, letterSpacing: 1 },
  cancelBtn:  { alignItems: "center", marginTop: spacing.sm, padding: spacing.sm },
  cancelBtnText: { fontFamily: font.mono, fontSize: 12, color: colors.muted },
});

// ---------------------------------------------------------------------------
// Config Screen
// ---------------------------------------------------------------------------
export interface MobileSessionConfig {
  patternType: PatternId;
  sensitivity: number;   // 0–100
  smoothing:   number;   // 0–100
}

interface Props {
  onStart: (config: MobileSessionConfig) => void;
}

export default function ConfigScreen({ onStart }: Props) {
  const [patternType, setPatternType] = useState<PatternId>("organic");
  const [sensitivity, setSensitivity] = useState(50);
  const [smoothing,   setSmoothing  ] = useState(50);
  const [loading,     setLoading    ] = useState(false);
  const [error,       setError      ] = useState("");
  const [modalOpen,   setModalOpen  ] = useState(false);

  const { bleState, connectedDevice, disconnect } = useMuseBLEContext();
  const isBleConnected = bleState === "connected";

  async function handleStart() {
    setLoading(true);
    setError("");
    try {
      await startSession({
        pattern_type:       patternType,
        signal_sensitivity: sensitivity / 100,
        emotion_smoothing:  smoothing   / 100,
        noise_control:      1,
        // If the phone is connected to the Muse 2 the backend skips its own BLE
        device_source:      isBleConnected ? "mobile" : undefined,
      });
      onStart({ patternType, sensitivity, smoothing });
    } catch (e: any) {
      setError(e?.message ?? "Failed to start session.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <View style={styles.root}>
      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">

        {/* ── Header ── */}
        <View style={styles.header}>
          <Text style={styles.wordmark}>SENTIO</Text>
          <Text style={styles.tagline}>emotion-driven fabric patterns</Text>
        </View>

        {/* ── Card ── */}
        <View style={styles.card}>
          <Text style={styles.cardTitle}>Configure Session</Text>

          {/* ── Headset status banner ── */}
          {isBleConnected && connectedDevice ? (
            <View style={styles.bleConnected}>
              <View style={styles.bleDot} />
              <View style={{ flex: 1 }}>
                <Text style={styles.bleDeviceName}>{connectedDevice.name}</Text>
                <Text style={styles.bleDeviceId}>Mobile Bluetooth · connected</Text>
              </View>
              <TouchableOpacity onPress={disconnect} style={styles.bleDisconnectBtn}>
                <Text style={styles.bleDisconnectText}>Disconnect</Text>
              </TouchableOpacity>
            </View>
          ) : (
            <View style={styles.bleNotConnected}>
              <Text style={styles.bleNotConnectedText}>
                ⚡ No headset — backend will use its own Bluetooth
              </Text>
            </View>
          )}

          {/* Pattern Type */}
          <View style={styles.field}>
            <Text style={styles.fieldLabel}>Pattern Type</Text>
            <View style={styles.patternGrid}>
              {PATTERNS.map((p) => (
                <TouchableOpacity
                  key={p.id}
                  style={[
                    styles.patternBtn,
                    patternType === p.id && styles.patternBtnActive,
                  ]}
                  onPress={() => setPatternType(p.id)}
                  activeOpacity={0.7}
                >
                  <PatternPreview type={p.id} active={patternType === p.id} />
                  <Text style={[styles.patternLabel, patternType === p.id && { color: colors.cyan }]}>
                    {p.label}
                  </Text>
                  <Text style={styles.patternDesc}>{p.desc}</Text>
                </TouchableOpacity>
              ))}
            </View>
          </View>

          {/* Signal Sensitivity */}
          <SimpleSlider
            label="Signal Sensitivity"
            value={sensitivity}
            onChange={setSensitivity}
            leftLabel="Low noise"
            rightLabel="High detail"
          />

          {/* State Smoothing */}
          <SimpleSlider
            label="State Smoothing"
            value={smoothing}
            onChange={setSmoothing}
            leftLabel="Reactive"
            rightLabel="Stable"
          />

          {/* Error */}
          {!!error && (
            <View style={styles.errorBox}>
              <Text style={styles.errorText}>{error}</Text>
            </View>
          )}

          {/* Start */}
          <TouchableOpacity
            style={[styles.startBtn, loading && styles.startBtnDisabled]}
            onPress={handleStart}
            disabled={loading}
            activeOpacity={0.8}
          >
            {loading
              ? <ActivityIndicator color={colors.bg} />
              : <Text style={styles.startBtnText}>Start Session →</Text>
            }
          </TouchableOpacity>
        </View>

      </ScrollView>

      {/* ── Floating gear button (bottom-right) ── */}
      <TouchableOpacity
        style={styles.gearBtn}
        onPress={() => setModalOpen(true)}
        activeOpacity={0.8}
      >
        <Text style={styles.gearIcon}>⚙️</Text>
      </TouchableOpacity>

      <DeviceModal visible={modalOpen} onClose={() => setModalOpen(false)} />
    </View>
  );
}

const styles = StyleSheet.create({
  root:    { flex: 1, backgroundColor: colors.bg },
  content: { padding: spacing.md, paddingBottom: 80, paddingTop: spacing.xl },

  header:   { alignItems: "center", marginBottom: spacing.xl },
  wordmark: { fontFamily: font.mono, fontSize: 28, fontWeight: "800", letterSpacing: 6, color: colors.cyan },
  tagline:  { fontFamily: font.mono, fontSize: 11, color: colors.muted, marginTop: spacing.xs, letterSpacing: 2 },

  card: {
    backgroundColor: colors.bg2,
    borderWidth:     1,
    borderColor:     colors.border,
    borderRadius:    radius.lg,
    padding:         spacing.lg,
  },
  cardTitle: { fontSize: 16, fontWeight: "700", color: colors.text, marginBottom: spacing.lg },

  field:      { marginBottom: spacing.md },
  fieldLabel: { fontFamily: font.mono, fontSize: 10, color: colors.muted, letterSpacing: 2, marginBottom: spacing.sm },

  patternGrid: { flexDirection: "row", flexWrap: "wrap", gap: spacing.sm },
  patternBtn: {
    width:           "47%",
    backgroundColor: colors.bg,
    borderWidth:     1,
    borderColor:     colors.border,
    borderRadius:    radius.md,
    padding:         spacing.sm,
  },
  patternBtnActive: { borderColor: colors.cyan + "88", backgroundColor: colors.cyan + "0d" },
  patternLabel: { fontFamily: font.mono, fontSize: 12, fontWeight: "700", color: colors.text },
  patternDesc:  { fontFamily: font.mono, fontSize: 9,  color: colors.muted, marginTop: 2 },

  errorBox: {
    backgroundColor: "#D00000" + "18",
    borderWidth:     1,
    borderColor:     "#D00000" + "55",
    borderRadius:    radius.md,
    padding:         spacing.sm,
    marginBottom:    spacing.md,
  },
  errorText: { fontFamily: font.mono, fontSize: 12, color: "#ff6b6b" },

  startBtn: {
    backgroundColor: colors.cyan,
    borderRadius:    radius.md,
    padding:         spacing.md,
    alignItems:      "center",
    marginTop:       spacing.sm,
  },
  startBtnDisabled: { opacity: 0.6 },
  startBtnText: { fontFamily: font.mono, fontSize: 14, fontWeight: "700", color: colors.bg, letterSpacing: 1 },

  gearBtn: {
    position:        "absolute",
    bottom:          spacing.xl,
    right:           spacing.lg,
    width:           52,
    height:          52,
    borderRadius:    26,
    backgroundColor: colors.cyan,
    alignItems:      "center",
    justifyContent:  "center",
    shadowColor:     colors.cyan,
    shadowOffset:    { width: 0, height: 0 },
    shadowOpacity:   0.45,
    shadowRadius:    10,
    elevation:       8,
  },
  gearIcon: { fontSize: 22 },

  // ── Headset status banner ───────────────────────────────────────────────
  bleConnected: {
    flexDirection:   "row",
    alignItems:      "center",
    backgroundColor: "#00ff8814",
    borderWidth:     1,
    borderColor:     "#4ade8044",
    borderRadius:    radius.md,
    padding:         spacing.sm,
    gap:             spacing.sm,
    marginBottom:    spacing.md,
  },
  bleDot: {
    width: 8, height: 8, borderRadius: 4,
    backgroundColor: "#4ade80",
    flexShrink: 0,
  },
  bleDeviceName:    { fontFamily: font.mono, fontSize: 12, fontWeight: "700", color: "#4ade80" },
  bleDeviceId:      { fontFamily: font.mono, fontSize: 9, color: colors.muted, marginTop: 1 },
  bleDisconnectBtn: { paddingHorizontal: spacing.sm },
  bleDisconnectText:{ fontFamily: font.mono, fontSize: 10, color: colors.muted },

  bleNotConnected: {
    backgroundColor: colors.bg,
    borderWidth:     1,
    borderColor:     colors.border,
    borderRadius:    radius.md,
    padding:         spacing.sm,
    marginBottom:    spacing.md,
    alignItems:      "center",
  },
  bleNotConnectedText: { fontFamily: font.mono, fontSize: 11, color: colors.muted },
});
