/**
 * SettingsScreen  (Ionic)
 * -----------------------
 * Backend URL setting, session status, demo-mode emotion overrides.
 */
import React, { useEffect, useState, useCallback } from "react";
import { IonPage, IonContent, IonSpinner } from "@ionic/react";
import { getStoredApiUrl, saveApiUrl } from "../lib/runtimeConfig";
import {
  getSessionStatus, sendManualOverride, stopSession,
  SessionStatus, EmotionKey, EMOTION_PRESETS,
} from "../lib/sentioApi";
import { useSentio } from "../lib/SentioContext";
import { colors, emotionColor, emotionLabel, spacing, radius } from "../theme";

const s = {
  scroll:  { padding: spacing.md, paddingBottom: 48 },
  statusRow: { display: "flex", alignItems: "center", gap: 8, marginBottom: spacing.lg },
  dot: (on: boolean) => ({
    width: 10, height: 10, borderRadius: 5,
    background: on ? colors.cyan : colors.muted, flexShrink: 0,
  }),
  statusText: { fontFamily: "monospace", fontSize: 13, color: colors.muted },
  section: { marginBottom: spacing.lg },
  sectionHead: {
    display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: spacing.sm,
  },
  sectionTitle: {
    fontFamily: "monospace", fontSize: 10, letterSpacing: 2, color: colors.muted,
    marginBottom: spacing.sm, display: "block",
  },
  fieldDesc: { fontSize: 12, color: colors.muted, lineHeight: 1.6, marginBottom: spacing.sm },
  input: {
    background: colors.bg2, border: `1px solid ${colors.border}`, borderRadius: radius.md,
    padding: spacing.sm, color: colors.text, fontFamily: "monospace", fontSize: 14,
    width: "100%", boxSizing: "border-box" as const, marginBottom: 4, outline: "none",
  },
  btn: {
    background: colors.cyan, borderRadius: radius.md, padding: spacing.md,
    border: "none", cursor: "pointer", width: "100%", marginTop: spacing.sm,
    fontFamily: "monospace", fontSize: 13, fontWeight: 700, color: colors.bg, letterSpacing: 1,
  },
  btnDisabled: { opacity: 0.5, cursor: "not-allowed" },
  card: {
    background: colors.bg2, border: `1px solid ${colors.border}`,
    borderRadius: radius.md, padding: spacing.md,
  },
  cardRow: { display: "flex", justifyContent: "space-between", padding: "5px 0" },
  cardLabel: { fontFamily: "monospace", fontSize: 12, color: colors.muted },
  cardValue: (col?: string) => ({ fontFamily: "monospace", fontSize: 12, color: col ?? colors.text }),
  emptyText: { fontFamily: "monospace", fontSize: 12, color: colors.muted, textAlign: "center" as const, padding: `${spacing.sm}px 0` },
  stopBtn: {
    background: "none", border: `1px solid #D0000066`, borderRadius: radius.md,
    padding: spacing.sm, cursor: "pointer", width: "100%", marginTop: spacing.sm,
    fontFamily: "monospace", fontSize: 12, color: "#D00000",
  },
  emotionGrid: { display: "flex", flexWrap: "wrap" as const, gap: spacing.sm },
  activeHint: { marginTop: spacing.sm, fontSize: 12, color: colors.muted, fontFamily: "monospace" },
} as const;

export default function SettingsScreen() {
  const { connected, reconnect } = useSentio();
  const [apiUrl,  setApiUrl ] = useState("");
  const [saving,  setSaving ] = useState(false);
  const [sessionStatus, setSessionStatus] = useState<SessionStatus | null>(null);
  const [statusLoading, setStatusLoading] = useState(false);
  const [activeEmotion, setActiveEmotion] = useState<EmotionKey | null>(null);
  const [overrideLoading, setOverrideLoading] = useState(false);

  useEffect(() => { getStoredApiUrl().then(setApiUrl); }, []);

  const refreshStatus = useCallback(async () => {
    if (!connected) { setSessionStatus(null); return; }
    setStatusLoading(true);
    try { setSessionStatus(await getSessionStatus()); }
    catch { setSessionStatus(null); }
    finally { setStatusLoading(false); }
  }, [connected]);

  useEffect(() => {
    refreshStatus();
    const id = setInterval(refreshStatus, 3000);
    return () => clearInterval(id);
  }, [refreshStatus]);

  async function handleSave() {
    const trimmed = apiUrl.trim();
    if (!trimmed || !/^https?:\/\//.test(trimmed)) {
      alert("URL must start with http:// or https://");
      return;
    }
    setSaving(true);
    await saveApiUrl(trimmed);
    await reconnect();
    setSaving(false);
  }

  async function handleOverride(emotion: EmotionKey) {
    setOverrideLoading(true);
    setActiveEmotion(emotion);
    try { await sendManualOverride(emotion); }
    catch (e: any) { alert(`Override failed: ${e?.message ?? "Could not reach backend."}`); setActiveEmotion(null); }
    finally { setOverrideLoading(false); }
  }

  async function handleStop() {
    try { await stopSession(); setActiveEmotion(null); await refreshStatus(); }
    catch (e: any) { alert(`Stop failed: ${e?.message}`); }
  }

  const stateColor = (st?: string) => {
    if (st === "running")    return colors.cyan;
    if (st === "connecting") return colors.amber;
    return colors.muted;
  };

  const EMOTIONS = Object.keys(EMOTION_PRESETS) as EmotionKey[];

  return (
    <IonPage>
      <IonContent style={{ "--background": colors.bg }}>
        <div style={s.scroll}>
          {/* WS indicator */}
          <div style={s.statusRow}>
            <div style={s.dot(connected)} />
            <span style={s.statusText}>{connected ? "WebSocket connected" : "Not connected"}</span>
          </div>

          {/* Backend URL */}
          <div style={s.section}>
            <span style={s.sectionTitle}>BACKEND URL</span>
            <p style={s.fieldDesc}>
              The full URL of the Sentio backend, e.g.{" "}
              <code style={{ color: colors.cyan }}>http://192.168.1.42:8000</code>
            </p>
            <input
              style={s.input}
              value={apiUrl}
              onChange={e => setApiUrl(e.target.value)}
              placeholder="http://127.0.0.1:8000"
              autoComplete="off"
              spellCheck={false}
            />
            <button
              style={{ ...s.btn, ...(saving ? s.btnDisabled : {}) }}
              onClick={handleSave}
              disabled={saving}
            >
              {saving ? "Connecting…" : "Save & Reconnect"}
            </button>
          </div>

          {/* Session status */}
          <div style={s.section}>
            <div style={s.sectionHead}>
              <span style={s.sectionTitle}>SESSION STATUS</span>
              {statusLoading && <IonSpinner name="dots" style={{ width: 16, height: 16, color: colors.muted }} />}
            </div>
            <div style={s.card}>
              {sessionStatus ? (
                <>
                  <div style={s.cardRow}>
                    <span style={s.cardLabel}>State</span>
                    <span style={s.cardValue(stateColor(sessionStatus.state))}>{sessionStatus.state.toUpperCase()}</span>
                  </div>
                  <div style={s.cardRow}>
                    <span style={s.cardLabel}>Session ID</span>
                    <span style={s.cardValue()}>{sessionStatus.session_id ? `${sessionStatus.session_id.slice(0, 8)}…` : "—"}</span>
                  </div>
                  <div style={s.cardRow}>
                    <span style={s.cardLabel}>Emotions logged</span>
                    <span style={s.cardValue()}>{sessionStatus.emotion_history_length}</span>
                  </div>
                  {sessionStatus.state === "running" && (
                    <button style={s.stopBtn} onClick={handleStop}>Stop Session</button>
                  )}
                </>
              ) : (
                <p style={s.emptyText}>{connected ? "Fetching status…" : "Connect to backend first"}</p>
              )}
            </div>
          </div>

          {/* Demo Mode */}
          <div style={s.section}>
            <span style={s.sectionTitle}>DEMO MODE</span>
            <p style={s.fieldDesc}>
              No headset? Inject a synthetic EEG frame — same presets as web Manual Mode.
            </p>
            <div style={s.emotionGrid}>
              {EMOTIONS.map(em => {
                const col = emotionColor[em.toLowerCase()] ?? colors.muted;
                const isActive = activeEmotion === em;
                return (
                  <button
                    key={em}
                    disabled={overrideLoading}
                    onClick={() => handleOverride(em)}
                    style={{
                      border: `1px solid ${col}${isActive ? "ff" : "44"}`,
                      background: isActive ? `${col}1a` : colors.bg2,
                      borderRadius: radius.md,
                      padding: `${spacing.sm}px ${spacing.md}px`,
                      cursor: "pointer",
                      fontFamily: "monospace", fontSize: 13, fontWeight: 700,
                      color: isActive ? col : colors.muted,
                    }}
                  >
                    {emotionLabel[em.toLowerCase()] ?? em}
                  </button>
                );
              })}
            </div>
            {activeEmotion && (
              <p style={s.activeHint}>
                Injecting{" "}
                <span style={{ color: emotionColor[activeEmotion.toLowerCase()] ?? colors.cyan }}>
                  {emotionLabel[activeEmotion.toLowerCase()] ?? activeEmotion}
                </span>
                {" "}— tap another to switch
              </p>
            )}
          </div>

          {/* About */}
          <div style={s.section}>
            <span style={s.sectionTitle}>ABOUT</span>
            <div style={s.card}>
              {[
                ["App",      "Sentio Mobile"],
                ["Version",  "1.0.0"],
                ["WS path",  "/ws/brain-stream"],
                ["AI model", "claude-haiku-4-5"],
                ["SDK",      "Ionic + Capacitor"],
              ].map(([label, value]) => (
                <div key={label} style={s.cardRow}>
                  <span style={s.cardLabel}>{label}</span>
                  <span style={s.cardValue()}>{value}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </IonContent>
    </IonPage>
  );
}
