/**
 * ConfigScreen  (Ionic)
 * ---------------------
 * Session configuration: pattern type, sensitivity, smoothing.
 * Gear icon opens settings modal for backend API URL.
 */
import React, { useEffect, useRef, useState } from "react";
import {
  IonPage, IonContent, IonModal, IonSpinner,
} from "@ionic/react";
import { getStoredApiUrl, saveApiUrl } from "../lib/runtimeConfig";
import { startSession } from "../lib/sentioApi";
import { useMuseBLEContext } from "../lib/MuseBLEContext";
import { colors, spacing, radius } from "../theme";

// ---------------------------------------------------------------------------
// Pattern options
// ---------------------------------------------------------------------------
const PATTERNS = [
  { id: "organic",   label: "Organic",   desc: "Flowing natural forms"   },
  { id: "geometric", label: "Geometric", desc: "Structured symmetry"     },
  { id: "fluid",     label: "Fluid",     desc: "Liquid motion patterns"  },
  { id: "textile",   label: "Textile",   desc: "Woven fabric inspired"   },
] as const;
type PatternId = typeof PATTERNS[number]["id"];

export interface MobileSessionConfig {
  patternType: PatternId;
  sensitivity: number;
  smoothing:   number;
}
interface Props { onStart: (c: MobileSessionConfig) => void }

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------
const s = {
  content: { background: colors.bg, minHeight: "100vh" },
  scroll:  { padding: `${spacing.xl}px ${spacing.md}px 80px`, maxWidth: 560, margin: "0 auto" },

  header:   { textAlign: "center" as const, marginBottom: spacing.xl },
  wordmark: {
    fontFamily: "monospace", fontSize: 28, fontWeight: 800,
    letterSpacing: 6, color: colors.cyan, margin: 0,
  },
  tagline: {
    fontFamily: "monospace", fontSize: 11, color: colors.muted,
    marginTop: spacing.xs, letterSpacing: 2,
  },

  card: {
    background: colors.bg2, border: `1px solid ${colors.border}`,
    borderRadius: radius.lg, padding: spacing.lg,
  },
  cardTitle: {
    fontFamily: "monospace", fontSize: 16, fontWeight: 700,
    color: colors.text, marginBottom: spacing.lg, marginTop: 0,
  },

  // BLE banner
  bleBanner: (connected: boolean) => ({
    display: "flex", alignItems: "center", gap: spacing.sm,
    background: connected ? "#00ff8814" : colors.bg,
    border: `1px solid ${connected ? "#4ade8044" : colors.border}`,
    borderRadius: radius.md, padding: spacing.sm, marginBottom: spacing.md,
  }),
  bleDot:     { width: 8, height: 8, borderRadius: 4, background: "#4ade80", flexShrink: 0 },
  bleName:    { fontFamily: "monospace", fontSize: 12, fontWeight: 700, color: "#4ade80", flex: 1 },
  bleSub:     { fontFamily: "monospace", fontSize: 9,  color: colors.muted, marginTop: 1 },
  bleDiscon:  { fontFamily: "monospace", fontSize: 10, color: colors.muted, background: "none", border: "none", cursor: "pointer", padding: `0 ${spacing.sm}px` },
  bleNone:    { fontFamily: "monospace", fontSize: 11, color: colors.muted, margin: 0 },

  fieldLabel: {
    fontFamily: "monospace", fontSize: 10, color: colors.muted,
    letterSpacing: 2, display: "block", marginBottom: spacing.sm,
  },
  patternGrid: { display: "grid", gridTemplateColumns: "1fr 1fr", gap: spacing.sm, marginBottom: spacing.md },
  patternBtn: (active: boolean) => ({
    background: active ? `${colors.cyan}0d` : colors.bg,
    border: `1px solid ${active ? `${colors.cyan}88` : colors.border}`,
    borderRadius: radius.md, padding: spacing.sm, cursor: "pointer", textAlign: "left" as const,
  }),
  patternPreview: (active: boolean) => ({
    width: "100%", height: 48, borderRadius: radius.sm,
    background: active ? `${colors.cyan}18` : colors.bg,
    border: `1px solid ${active ? `${colors.cyan}55` : colors.border}`,
    marginBottom: spacing.xs, overflow: "hidden", position: "relative" as const,
    display: "flex", alignItems: "center", justifyContent: "center",
  }),
  patternLabel: (active: boolean) => ({
    fontFamily: "monospace", fontSize: 12, fontWeight: 700,
    color: active ? colors.cyan : colors.text, margin: 0,
  }),
  patternDesc: { fontFamily: "monospace", fontSize: 9, color: colors.muted, marginTop: 2 },

  // Slider
  sliderWrap: { marginBottom: spacing.md },
  sliderHead: { display: "flex", justifyContent: "space-between", marginBottom: 6 },
  sliderLabel:{ fontFamily: "monospace", fontSize: 11, color: colors.muted },
  sliderPct:  { fontFamily: "monospace", fontSize: 11, color: colors.cyan },
  sliderTrack:{ height: 6, background: colors.border, borderRadius: 999, position: "relative" as const, cursor: "pointer" },
  sliderLabels:{ display: "flex", justifyContent: "space-between", marginTop: 4 },
  sliderSide: { fontFamily: "monospace", fontSize: 9, color: colors.muted },

  errorBox: {
    background: "#D0000018", border: `1px solid #D0000055`,
    borderRadius: radius.md, padding: spacing.sm, marginBottom: spacing.md,
    fontFamily: "monospace", fontSize: 12, color: "#ff6b6b",
  },
  startBtn: (loading: boolean) => ({
    background: colors.cyan, borderRadius: radius.md, padding: spacing.md,
    width: "100%", border: "none", cursor: loading ? "not-allowed" : "pointer",
    fontFamily: "monospace", fontSize: 14, fontWeight: 700, color: colors.bg,
    letterSpacing: 1, opacity: loading ? 0.6 : 1, marginTop: spacing.sm,
    display: "flex", alignItems: "center", justifyContent: "center", gap: 8,
  }),

  // Gear FAB
  gear: {
    position: "fixed" as const, bottom: spacing.xl, right: spacing.lg,
    width: 52, height: 52, borderRadius: 26,
    background: colors.cyan, border: "none", cursor: "pointer",
    fontSize: 22, display: "flex", alignItems: "center", justifyContent: "center",
    boxShadow: `0 0 20px ${colors.cyan}70`, zIndex: 100,
  },

  // Modal
  modalOverlay: {
    position: "fixed" as const, inset: 0,
    background: "#00000088", zIndex: 200,
    display: "flex", flexDirection: "column" as const, justifyContent: "flex-end",
  },
  modalSheet: {
    background: colors.bg2, borderRadius: "20px 20px 0 0",
    padding: spacing.lg, paddingBottom: 40,
    border: `1px solid ${colors.border}`, borderBottom: "none",
  },
  modalHandle: {
    width: 40, height: 4, borderRadius: 2,
    background: colors.border, margin: "0 auto", marginBottom: spacing.lg,
  },
  modalTitle: {
    fontFamily: "monospace", fontSize: 14, fontWeight: 700,
    color: colors.text, letterSpacing: 2, marginBottom: spacing.md, marginTop: 0,
  },
  modalFieldLabel: {
    fontFamily: "monospace", fontSize: 10, color: colors.muted,
    letterSpacing: 2, display: "block", marginBottom: 6,
  },
  modalInput: {
    background: colors.bg, border: `1px solid ${colors.border}`, borderRadius: radius.md,
    padding: spacing.sm, color: colors.text, fontFamily: "monospace", fontSize: 14,
    width: "100%", boxSizing: "border-box" as const, marginBottom: 4, outline: "none",
  },
  modalHint:  { fontFamily: "monospace", fontSize: 10, color: colors.muted, marginBottom: 4 },
  modalSave: {
    background: colors.cyan, borderRadius: radius.md, padding: spacing.md,
    width: "100%", border: "none", cursor: "pointer",
    fontFamily: "monospace", fontSize: 13, fontWeight: 700, color: colors.bg,
    letterSpacing: 1, marginTop: spacing.lg,
  },
  modalCancel: {
    background: "none", border: "none", cursor: "pointer", width: "100%",
    padding: spacing.sm, fontFamily: "monospace", fontSize: 12, color: colors.muted,
    marginTop: spacing.sm,
  },
} as const;

// ---------------------------------------------------------------------------
// Settings modal
// ---------------------------------------------------------------------------
function SettingsModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const [url, setUrl] = useState("");

  useEffect(() => {
    if (open) getStoredApiUrl().then(setUrl);
  }, [open]);

  async function save() {
    if (url.trim() && !/^https?:\/\//.test(url.trim())) {
      alert("URL must start with http:// or https://");
      return;
    }
    if (url.trim()) await saveApiUrl(url.trim());
    onClose();
  }

  if (!open) return null;

  return (
    <div style={s.modalOverlay} onClick={onClose}>
      <div style={s.modalSheet} onClick={e => e.stopPropagation()}>
        <div style={s.modalHandle} />
        <h3 style={s.modalTitle}>Backend Settings</h3>

        <label style={s.modalFieldLabel}>API URL</label>
        <input
          style={s.modalInput}
          value={url}
          onChange={e => setUrl(e.target.value)}
          placeholder="http://192.168.1.42:8000"
          autoComplete="off"
          spellCheck={false}
        />
        <p style={s.modalHint}>Address of the Sentio backend server.</p>

        <button style={s.modalSave} onClick={save}>Save</button>
        <button style={s.modalCancel} onClick={onClose}>Cancel</button>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Simple range slider
// ---------------------------------------------------------------------------
function Slider({ label, value, onChange, leftLabel, rightLabel }: {
  label: string; value: number; onChange: (v: number) => void;
  leftLabel?: string; rightLabel?: string;
}) {
  return (
    <div style={s.sliderWrap}>
      <div style={s.sliderHead}>
        <span style={s.sliderLabel}>{label}</span>
        <span style={s.sliderPct}>{value}%</span>
      </div>
      <input
        type="range" min={0} max={100} value={value}
        onChange={e => onChange(Number(e.target.value))}
        style={{
          width: "100%", accentColor: colors.cyan,
          cursor: "pointer", height: 6,
        }}
      />
      {(leftLabel || rightLabel) && (
        <div style={s.sliderLabels}>
          <span style={s.sliderSide}>{leftLabel}</span>
          <span style={s.sliderSide}>{rightLabel}</span>
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Pattern preview (pure CSS shapes)
// ---------------------------------------------------------------------------
function PatternPreview({ type, active }: { type: PatternId; active: boolean }) {
  const col = active ? colors.cyan : colors.muted;
  return (
    <div style={s.patternPreview(active)}>
      {type === "organic" && (
        <>
          <div style={{ position: "absolute", left: 8, top: 6, width: 36, height: 36, borderRadius: 18, border: `1px solid ${col}`, opacity: 0.6 }} />
          <div style={{ position: "absolute", left: 24, top: 12, width: 24, height: 24, borderRadius: 12, border: `1px solid ${col}`, opacity: 0.4 }} />
        </>
      )}
      {type === "geometric" && (
        <>
          <div style={{ width: 24, height: 24, border: `1px solid ${col}`, opacity: 0.6, transform: "rotate(15deg)" }} />
          <div style={{ position: "absolute", width: 18, height: 18, border: `1px solid ${col}`, opacity: 0.35, transform: "rotate(38deg)" }} />
        </>
      )}
      {type === "fluid" && (
        <div style={{ width: "60%", borderBottom: `1.5px solid ${col}`, opacity: 0.65 }} />
      )}
      {type === "textile" && (
        <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
          {[0, 1, 2].map(i => (
            <div key={i} style={{ width: 1, height: 28, borderLeft: `1px solid ${col}`, opacity: 0.35 }} />
          ))}
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Config Screen
// ---------------------------------------------------------------------------
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
    <IonPage>
      <IonContent style={{ "--background": colors.bg }}>
        <div style={s.scroll}>
          {/* Header */}
          <div style={s.header}>
            <h1 style={s.wordmark}>SENTIO</h1>
            <p style={s.tagline}>emotion-driven fabric patterns</p>
          </div>

          <div style={s.card}>
            <h2 style={s.cardTitle}>Configure Session</h2>

            {/* Headset status */}
            {isBleConnected && connectedDevice ? (
              <div style={s.bleBanner(true)}>
                <div style={s.bleDot} />
                <div style={{ flex: 1 }}>
                  <p style={s.bleName}>{connectedDevice.name}</p>
                  <p style={s.bleSub}>Mobile Bluetooth · connected</p>
                </div>
                <button style={s.bleDiscon} onClick={disconnect}>Disconnect</button>
              </div>
            ) : (
              <div style={s.bleBanner(false)}>
                <p style={s.bleNone}>⚡ No headset — backend will use its own Bluetooth</p>
              </div>
            )}

            {/* Pattern type */}
            <label style={s.fieldLabel}>PATTERN TYPE</label>
            <div style={s.patternGrid}>
              {PATTERNS.map(p => (
                <button
                  key={p.id}
                  style={s.patternBtn(patternType === p.id)}
                  onClick={() => setPatternType(p.id)}
                >
                  <PatternPreview type={p.id} active={patternType === p.id} />
                  <p style={s.patternLabel(patternType === p.id)}>{p.label}</p>
                  <p style={s.patternDesc}>{p.desc}</p>
                </button>
              ))}
            </div>

            {/* Sliders */}
            <Slider
              label="Signal Sensitivity" value={sensitivity} onChange={setSensitivity}
              leftLabel="Low noise" rightLabel="High detail"
            />
            <Slider
              label="State Smoothing" value={smoothing} onChange={setSmoothing}
              leftLabel="Reactive" rightLabel="Stable"
            />

            {/* Error */}
            {!!error && <div style={s.errorBox}>{error}</div>}

            {/* Start button */}
            <button
              style={s.startBtn(loading)}
              onClick={handleStart}
              disabled={loading}
            >
              {loading
                ? <><IonSpinner name="dots" style={{ width: 16, height: 16 }} /> Starting…</>
                : "Start Session →"}
            </button>
          </div>
        </div>

        {/* Gear FAB */}
        <button style={s.gear} onClick={() => setModalOpen(true)}>⚙️</button>

        <SettingsModal open={modalOpen} onClose={() => setModalOpen(false)} />
      </IonContent>
    </IonPage>
  );
}
