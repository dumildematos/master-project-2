import React from "react";
import { motion } from "framer-motion";
import { Brain, ChevronRight, Settings } from "lucide-react";
import type { SessionConfig } from "../types";
import DeviceNotConnectedModal from "./DeviceNotConnectedModal";

const patternTypes = [
  { id: "organic",   label: "Organic",   desc: "Flowing natural forms"  },
  { id: "geometric", label: "Geometric", desc: "Structured symmetry"    },
  { id: "fluid",     label: "Fluid",     desc: "Liquid motion patterns" },
  { id: "textile",   label: "Textile",   desc: "Woven fabric inspired"  },
];

interface Props {
  config:    SessionConfig;
  setConfig: (c: SessionConfig) => void;
  onStart:   () => void;
}

export default function ConfigurationScreen({ config, setConfig, onStart }: Props) {
  const [showDevicePopup,       setShowDevicePopup]       = React.useState(false);
  const [showNotConnectedModal, setShowNotConnectedModal] = React.useState(false);
  const [macAddress,            setMacAddress]            = React.useState("");
  const [apiUrl,                setApiUrl]                = React.useState("http://localhost:8000");
  const [apiUrlDraft,           setApiUrlDraft]           = React.useState("http://localhost:8000");
  const [loading,               setLoading]               = React.useState(false);
  const [retrying,              setRetrying]              = React.useState(false);

  React.useEffect(() => {
    const storedMac = localStorage.getItem("muse2MacAddress");
    if (storedMac) setMacAddress(storedMac);

    const storedApi = localStorage.getItem("sentioApiUrl");
    if (storedApi) { setApiUrl(storedApi); setApiUrlDraft(storedApi); }
  }, []);

  const handleSaveSettings = (e: React.FormEvent) => {
    e.preventDefault();
    const trimmed = apiUrlDraft.replace(/\/$/, ""); // strip trailing slash
    setApiUrl(trimmed);
    localStorage.setItem("sentioApiUrl",      trimmed);
    localStorage.setItem("muse2MacAddress",   macAddress);
    setShowDevicePopup(false);
  };

  const isValid = !!config.patternType;

  /* ── Core session-start request ─────────────────────────────────────── */
  async function requestSessionStart(): Promise<"ok" | "device_error" | "backend_offline"> {
    try {
      const res = await fetch(`${apiUrl}/api/session/start`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        signal: AbortSignal.timeout(6000),
        body: JSON.stringify({
          pattern_type:       config.patternType,
          signal_sensitivity: config.sensitivity / 100,
          noise_control:      1.0,
          mac_address:        macAddress || undefined,
        }),
      });

      if (res.ok) {
        const data = await res.json();
        localStorage.setItem("sentioSession", JSON.stringify({ ...config, ...data }));
        return "ok";
      }

      // 400 / 500 → device connection error from backend
      if (res.status === 400 || res.status === 500) return "device_error";

      // 404 → endpoint not implemented yet, let it through
      if (res.status === 404) return "ok";

      return "device_error";
    } catch {
      // fetch threw → backend is not reachable at all
      return "backend_offline";
    }
  }

  /* ── "Start Session" button click ──────────────────────────────────── */
  const handleStart = async () => {
    if (!isValid || loading) return;
    setLoading(true);

    const result = await requestSessionStart();
    setLoading(false);

    if (result === "ok") {
      onStart();
    } else {
      // device_error OR backend_offline → show the modal
      setShowNotConnectedModal(true);
    }
  };

  /* ── "Try Again" inside the modal ──────────────────────────────────── */
  const handleRetry = async () => {
    setRetrying(true);
    const result = await requestSessionStart();
    setRetrying(false);

    if (result === "ok") {
      setShowNotConnectedModal(false);
      onStart();
    }
    // If still failing, modal stays open with error tips visible
  };

  /* ── "Continue Without Device" ─────────────────────────────────────── */
  const handleContinueAnyway = () => {
    setShowNotConnectedModal(false);
    onStart();
  };

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0, y: -20 }}
      transition={{ duration: 0.5 }}
      className="min-h-screen flex flex-col items-center justify-center px-4 py-12 relative"
    >
      {/* Loading toast */}
      {loading && (
        <div className="fixed top-6 left-1/2 -translate-x-1/2 z-40 bg-primary text-primary-foreground px-6 py-3 rounded-xl shadow-lg text-sm flex items-center gap-3">
          <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z" />
          </svg>
          Checking device…
        </div>
      )}

      {/* Logo */}
      <motion.div
        initial={{ y: -20, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.1 }}
        className="flex items-center gap-3 mb-2"
      >
        <Brain className="w-8 h-8 text-primary" />
        <h1 className="text-4xl font-bold tracking-tight glow-text-cyan">Sentio</h1>
      </motion.div>

      <motion.p
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.2 }}
        className="text-muted-foreground text-sm mb-10 mono"
      >
        emotion-driven fabric patterns
      </motion.p>

      {/* Config card */}
      <motion.div
        initial={{ y: 30, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.3, duration: 0.6 }}
        className="glass-card gradient-border p-8 w-full max-w-lg space-y-7"
      >
        <h2 className="text-lg font-semibold">Configure Session</h2>

        {/* Pattern Type */}
        <div className="space-y-2">
          <label className="text-sm text-muted-foreground mono">Pattern Type</label>
          <div className="grid grid-cols-2 gap-3">
            {patternTypes.map((p) => {
              const active = config.patternType === p.id;
              return (
                <button
                  key={p.id}
                  onClick={() => setConfig({ ...config, patternType: p.id })}
                  className={`rounded-xl p-4 text-left transition-all border ${
                    active
                      ? "bg-primary/10 border-primary/50"
                      : "bg-muted/20 border-border/30 hover:border-border/60"
                  }`}
                >
                  <PatternPreview type={p.id} active={active} />
                  <span className={`text-sm font-medium block mt-2 ${active ? "text-primary" : "text-foreground"}`}>
                    {p.label}
                  </span>
                  <span className="text-xs text-muted-foreground">{p.desc}</span>
                </button>
              );
            })}
          </div>
        </div>

        {/* Signal Sensitivity */}
        <div className="space-y-3">
          <div className="flex justify-between items-center">
            <label className="text-sm text-muted-foreground mono">Signal Sensitivity</label>
            <span className="mono text-xs text-primary">{config.sensitivity}%</span>
          </div>
          <input
            type="range" min={0} max={100}
            value={config.sensitivity}
            onChange={(e) => setConfig({ ...config, sensitivity: Number(e.target.value) })}
            className="w-full h-1.5 bg-muted rounded-full appearance-none cursor-pointer accent-primary
              [&::-webkit-slider-thumb]:appearance-none
              [&::-webkit-slider-thumb]:w-4 [&::-webkit-slider-thumb]:h-4
              [&::-webkit-slider-thumb]:bg-primary [&::-webkit-slider-thumb]:rounded-full
              [&::-webkit-slider-thumb]:shadow-[0_0_10px_hsl(187_80%_55%/0.5)]"
          />
          <div className="flex justify-between text-xs text-muted-foreground mono">
            <span>Low noise</span>
            <span>High detail</span>
          </div>
        </div>

        {/* Start button */}
        <button
          disabled={!isValid || loading}
          onClick={handleStart}
          className="w-full py-3.5 rounded-xl font-semibold text-sm flex items-center justify-center gap-2 transition-all
            disabled:opacity-30 disabled:cursor-not-allowed
            bg-primary text-primary-foreground
            hover:shadow-[0_0_30px_hsl(187_80%_55%/0.35)]"
        >
          Start Session
          <ChevronRight className="w-4 h-4" />
        </button>
      </motion.div>

      {/* Device settings FAB */}
      <button
        className="fixed bottom-6 right-6 z-40 bg-primary text-primary-foreground rounded-full p-4 shadow-lg
          hover:bg-primary/80 transition-all hover:shadow-[0_0_20px_hsl(187_80%_55%/0.4)]"
        onClick={() => setShowDevicePopup(true)}
        aria-label="Device Settings"
      >
        <Settings className="w-5 h-5" />
      </button>

      {/* Device settings popup */}
      {showDevicePopup && (
        <div
          className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-end justify-end"
          onClick={() => setShowDevicePopup(false)}
        >
          <motion.div
            initial={{ opacity: 0, y: 16, scale: 0.97 }}
            animate={{ opacity: 1, y: 0,  scale: 1    }}
            transition={{ type: "spring", stiffness: 280, damping: 24 }}
            className="glass-card gradient-border p-6 m-6 w-full max-w-sm flex flex-col gap-5"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Header */}
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Settings className="w-4 h-4 text-primary" />
                <h3 className="text-base font-semibold">Device Settings</h3>
              </div>
              <button
                onClick={() => setShowDevicePopup(false)}
                className="text-muted-foreground hover:text-foreground transition-colors p-1"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleSaveSettings} className="flex flex-col gap-5">

              {/* API URL */}
              <div className="flex flex-col gap-1.5">
                <label className="mono text-xs text-muted-foreground uppercase tracking-widest">
                  Backend API URL
                </label>
                <input
                  type="url"
                  value={apiUrlDraft}
                  onChange={(e) => setApiUrlDraft(e.target.value)}
                  placeholder="http://localhost:8000"
                  className="bg-muted/50 border border-border/50 rounded-xl px-4 py-3 text-sm text-foreground
                    placeholder:text-muted-foreground/40 focus:outline-none focus:ring-2 focus:ring-primary/40
                    transition-all"
                  required
                />
                <p className="mono text-[10px] text-muted-foreground">
                  Current: <span className="text-primary">{apiUrl}</span>
                </p>
              </div>

              {/* Divider */}
              <div className="border-t border-border/30" />

              {/* MAC Address */}
              <div className="flex flex-col gap-1.5">
                <label className="mono text-xs text-muted-foreground uppercase tracking-widest">
                  Muse 2 MAC Address
                </label>
                <input
                  type="text"
                  value={macAddress}
                  onChange={(e) => setMacAddress(e.target.value)}
                  placeholder="XX:XX:XX:XX:XX:XX"
                  className="bg-muted/50 border border-border/50 rounded-xl px-4 py-3 text-sm text-foreground
                    placeholder:text-muted-foreground/40 focus:outline-none focus:ring-2 focus:ring-primary/40
                    transition-all"
                />
                <p className="mono text-[10px] text-muted-foreground">
                  Leave blank to use the value from your backend config
                </p>
              </div>

              {/* Save */}
              <button
                type="submit"
                className="w-full py-2.5 rounded-xl font-semibold text-sm
                  bg-primary text-primary-foreground
                  hover:shadow-[0_0_20px_hsl(187_80%_55%/0.35)] transition-all"
              >
                Save Settings
              </button>
            </form>
          </motion.div>
        </div>
      )}

      {/* Device not connected modal */}
      <DeviceNotConnectedModal
        open={showNotConnectedModal}
        onClose={() => setShowNotConnectedModal(false)}
        onRetry={handleRetry}
        onContinueAnyway={handleContinueAnyway}
        retrying={retrying}
      />
    </motion.div>
  );
}

/* ── Pattern preview SVG ──────────────────────────────────────────────── */
function PatternPreview({ type, active }: { type: string; active: boolean }) {
  const color = active ? "hsl(187 80% 55%)" : "hsl(220 15% 35%)";
  return (
    <svg viewBox="0 0 60 40" className="w-full h-10 rounded-lg overflow-hidden">
      <rect width="60" height="40" fill="hsl(230 20% 11%)" />
      {type === "organic" && (
        <>
          <circle cx="15" cy="20" r="12" fill="none" stroke={color} strokeWidth="0.8" opacity="0.6" />
          <circle cx="35" cy="15" r="8"  fill="none" stroke={color} strokeWidth="0.8" opacity="0.4" />
          <circle cx="48" cy="28" r="10" fill="none" stroke={color} strokeWidth="0.8" opacity="0.5" />
        </>
      )}
      {type === "geometric" && (
        <>
          <rect x="5" y="5" width="15" height="15" fill="none" stroke={color} strokeWidth="0.8" opacity="0.6" transform="rotate(15 12 12)" />
          <polygon points="35,5 50,20 35,35 20,20" fill="none" stroke={color} strokeWidth="0.8" opacity="0.5" />
        </>
      )}
      {type === "fluid" && (
        <path d="M0,25 Q15,5 30,20 Q45,35 60,15" fill="none" stroke={color} strokeWidth="1.2" opacity="0.6" />
      )}
      {type === "textile" && (
        <>
          {[0,10,20,30,40,50].map((x) => (
            <line key={`v${x}`} x1={x} y1="0" x2={x} y2="40" stroke={color} strokeWidth="0.5" opacity="0.3" />
          ))}
          {[0,10,20,30].map((y) => (
            <line key={`h${y}`} x1="0" y1={y} x2="60" y2={y} stroke={color} strokeWidth="0.5" opacity="0.3" />
          ))}
        </>
      )}
    </svg>
  );
}
