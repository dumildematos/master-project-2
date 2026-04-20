/* eslint-disable @typescript-eslint/no-explicit-any */
import { motion } from "framer-motion";
import { Brain, ChevronRight } from "lucide-react";
import type { SessionConfig, GridSize } from "@/pages/Index";
import React from "react";

const apiBaseUrl = import.meta.env.VITE_API_BASE_URL;

const patternTypes = [
  { id: "organic", label: "Organic", desc: "Flowing natural forms" },
  { id: "geometric", label: "Geometric", desc: "Structured symmetry" },
  { id: "fluid", label: "Fluid", desc: "Liquid motion patterns" },
  { id: "textile", label: "Textile", desc: "Woven fabric inspired" },
];

const genders = ["Female", "Male", "Non-binary", "Prefer not to say"];

// Grid size presets — "fit" uses the physical hardware max stored in settings
const GRID_PRESETS: { id: GridSize; label: string; w: number; h: number }[] = [
  { id: "8x8",   label: "8 × 8",   w: 8,  h: 8  },
  { id: "16x16", label: "16 × 16", w: 16, h: 16 },
  { id: "32x32", label: "32 × 32", w: 32, h: 32 },
  { id: "64x64", label: "64 × 64", w: 64, h: 64 },
  { id: "fit",   label: "Fit",     w: 0,  h: 0  },
];

/** Resolve actual matrix dimensions for a given grid size preset. */
function resolveGrid(gridSize: GridSize): { w: number; h: number } {
  if (gridSize === "fit") {
    return {
      w: Number(localStorage.getItem("matrixWidth")  || 16),
      h: Number(localStorage.getItem("matrixHeight") || 16),
    };
  }
  const preset = GRID_PRESETS.find((p) => p.id === gridSize);
  return { w: preset?.w ?? 16, h: preset?.h ?? 16 };
}

interface Props {
  config: SessionConfig;
  setConfig: (c: SessionConfig) => void;
  onStart: () => void;
}

const ConfigurationScreen = ({ config, setConfig, onStart }: Props) => {
    const [showDevicePopup, setShowDevicePopup] = React.useState(false);
    const [macAddress, setMacAddress] = React.useState("");
    const [gridW, setGridW] = React.useState(16);
    const [gridH, setGridH] = React.useState(16);
    const [settingsTab, setSettingsTab] = React.useState<"device" | "grid">("device");

    React.useEffect(() => {
      const storedMac = localStorage.getItem("muse2MacAddress");
      if (storedMac) setMacAddress(storedMac);
      const storedW = localStorage.getItem("matrixWidth");
      const storedH = localStorage.getItem("matrixHeight");
      if (storedW) setGridW(Number(storedW));
      if (storedH) setGridH(Number(storedH));
    }, []);

    const handleSaveSettings = (e: React.FormEvent) => {
      e.preventDefault();
      if (macAddress) localStorage.setItem("muse2MacAddress", macAddress);
      localStorage.setItem("matrixWidth",  String(Math.max(1, gridW)));
      localStorage.setItem("matrixHeight", String(Math.max(1, gridH)));
      setShowDevicePopup(false);
    };
  const isValid = config.age && config.gender && config.patternType;
  const [errorMsg, setErrorMsg] = React.useState("");
  const [loading, setLoading] = React.useState(false);

  const handleStartSession = async () => {
    if (!isValid) return;
    setLoading(true);
    try {
      const response = await fetch(`${apiBaseUrl}/api/session/start`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          age: config.age,
          gender: config.gender,
          pattern_type: config.patternType,
          signal_sensitivity: config.sensitivity / 100,
          noise_control: 1,
          mac_address: macAddress || undefined,
          matrix_width:  resolveGrid(config.gridSize).w,
          matrix_height: resolveGrid(config.gridSize).h,
        }),
      });
      if (!response.ok) {
        const err = await response.json();
        if (err?.detail) {
          if (Array.isArray(err.detail)) {
            const messages = err.detail.map((d: any) => {
              const loc = d.loc?.join(".") || "";
              return `${loc.replace("body.", "")}: ${d.msg}`;
            });
            setErrorMsg(messages.join("\n"));
          } else if (typeof err.detail === "string") {
            setErrorMsg(err.detail);
          } else {
            setErrorMsg("Failed to start session.");
          }
        } else {
          setErrorMsg(err?.message || "Failed to start session.");
        }
        setLoading(false);
        return;
      }
      const sessionData = await response.json();
      const sessionToStore = {
        ...config,
        session_id: sessionData.session_id,
        status: sessionData.status,
      };
      localStorage.setItem("sentioSession", JSON.stringify(sessionToStore));
      setLoading(false);
      onStart();
    } catch (error) {
      setErrorMsg("Failed to start session. Please try again.");
      setLoading(false);
      console.error("Failed to start session", error);
    }
  };

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0, y: -20 }}
      transition={{ duration: 0.5 }}
      className="min-h-screen flex flex-col items-center justify-center px-4 py-12 relative"
    >
      {/* Loading Spinner */}
      {loading && (
        <div className="fixed top-6 left-1/2 -translate-x-1/2 z-50 bg-primary text-white px-6 py-3 rounded-xl shadow-lg font-semibold text-sm flex items-center gap-3">
          <svg className="animate-spin h-5 w-5 mr-2" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="white" strokeWidth="4" fill="none" />
            <path className="opacity-75" fill="white" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z" />
          </svg>
          Starting session...
        </div>
      )}
      {/* Error Popup */}
      {errorMsg && (
        <div className="fixed top-6 left-1/2 -translate-x-1/2 z-50 bg-red-600 text-white px-6 py-3 rounded-xl shadow-lg font-semibold text-sm">
          {errorMsg}
          <button className="ml-4 text-xs underline" onClick={() => setErrorMsg("")}>Dismiss</button>
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
            {/* Floating Gear Button */}
            <button
              className="fixed bottom-6 right-6 z-50 bg-primary text-white rounded-full p-4 shadow-lg hover:bg-primary/80 transition-all"
              onClick={() => setShowDevicePopup(true)}
              aria-label="Device Settings"
            >
              <svg width="24" height="24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="lucide lucide-settings"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09a1.65 1.65 0 0 0-1-1.51 1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09c.7 0 1.34-.4 1.51-1a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06c.48.48 1.17.6 1.82.33.65-.27 1-1.02 1-1.51V3a2 2 0 0 1 4 0v.09c0 .49.35 1.24 1 1.51.65.27 1.34.15 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82c.17.6.81 1 1.51 1H21a2 2 0 0 1 0 4h-.09c-.7 0-1.34.4-1.51 1Z"/></svg>
            </button>

            {/* Settings Popup */}
            {showDevicePopup && (
              <div className="fixed inset-0 bg-black/50 z-50 flex items-end justify-end">
                <motion.div
                  initial={{ opacity: 0, y: 24, scale: 0.97 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: 16 }}
                  transition={{ type: "spring", stiffness: 280, damping: 24 }}
                  className="m-6 mb-24 w-80 rounded-2xl shadow-2xl overflow-hidden"
                  style={{
                    background: "hsl(230 25% 10%)",
                    border: "1px solid hsl(220 20% 22%)",
                  }}
                >
                  {/* Header */}
                  <div className="flex items-center justify-between px-5 pt-5 pb-3">
                    <span className="text-sm font-semibold text-foreground font-mono tracking-wide">Settings</span>
                    <button
                      onClick={() => setShowDevicePopup(false)}
                      className="text-muted-foreground hover:text-foreground transition-colors"
                      aria-label="Close"
                    >
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round">
                        <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
                      </svg>
                    </button>
                  </div>

                  {/* Tabs */}
                  <div className="flex gap-1 mx-5 mb-4 bg-muted/20 rounded-xl p-1">
                    {(["device", "grid"] as const).map((tab) => (
                      <button
                        key={tab}
                        onClick={() => setSettingsTab(tab)}
                        className={`flex-1 py-1.5 rounded-lg text-xs font-mono font-medium transition-all capitalize ${
                          settingsTab === tab
                            ? "bg-primary/20 text-primary border border-primary/30"
                            : "text-muted-foreground hover:text-foreground"
                        }`}
                      >
                        {tab === "device" ? "📡  Device" : "⊞  Grid"}
                      </button>
                    ))}
                  </div>

                  {/* Tab Content */}
                  <form onSubmit={handleSaveSettings} className="px-5 pb-5 flex flex-col gap-4">

                    {settingsTab === "device" && (
                      <div className="flex flex-col gap-3">
                        <div className="flex flex-col gap-1.5">
                          <label className="text-xs text-muted-foreground font-mono">Muse 2 MAC Address</label>
                          <input
                            type="text"
                            value={macAddress}
                            onChange={e => setMacAddress(e.target.value)}
                            placeholder="XX:XX:XX:XX:XX:XX"
                            className="w-full bg-muted/30 border border-border/40 rounded-xl px-3 py-2.5 text-sm font-mono text-foreground placeholder:text-muted-foreground/40 focus:outline-none focus:ring-2 focus:ring-primary/40 transition-all"
                          />
                          <p className="text-xs text-muted-foreground/60 font-mono">
                            Found via <code className="bg-muted/40 px-1 rounded">hcitool scan</code> or nRF Connect
                          </p>
                        </div>
                      </div>
                    )}

                    {settingsTab === "grid" && (
                      <div className="flex flex-col gap-3">
                        <p className="text-xs text-muted-foreground font-mono leading-relaxed">
                          Set the LED matrix dimensions to match your physical hardware.
                          These values are used by the mockup and sent to the backend.
                        </p>

                        <div className="grid grid-cols-2 gap-3">
                          <div className="flex flex-col gap-1.5">
                            <label className="text-xs text-muted-foreground font-mono">Columns (W)</label>
                            <input
                              type="number"
                              min={1}
                              max={64}
                              value={gridW}
                              onChange={e => setGridW(Number(e.target.value))}
                              className="w-full bg-muted/30 border border-border/40 rounded-xl px-3 py-2.5 text-sm font-mono text-foreground text-center focus:outline-none focus:ring-2 focus:ring-primary/40 transition-all"
                            />
                          </div>
                          <div className="flex flex-col gap-1.5">
                            <label className="text-xs text-muted-foreground font-mono">Rows (H)</label>
                            <input
                              type="number"
                              min={1}
                              max={64}
                              value={gridH}
                              onChange={e => setGridH(Number(e.target.value))}
                              className="w-full bg-muted/30 border border-border/40 rounded-xl px-3 py-2.5 text-sm font-mono text-foreground text-center focus:outline-none focus:ring-2 focus:ring-primary/40 transition-all"
                            />
                          </div>
                        </div>

                        {/* Common presets */}
                        <div className="flex flex-col gap-1.5">
                          <label className="text-xs text-muted-foreground font-mono">Quick Presets</label>
                          <div className="grid grid-cols-3 gap-2">
                            {[
                              { label: "8×8",   w: 8,  h: 8  },
                              { label: "10×20", w: 10, h: 20 },
                              { label: "16×16", w: 16, h: 16 },
                            ].map((p) => (
                              <button
                                key={p.label}
                                type="button"
                                onClick={() => { setGridW(p.w); setGridH(p.h); }}
                                className={`py-1.5 rounded-lg text-xs font-mono border transition-all ${
                                  gridW === p.w && gridH === p.h
                                    ? "bg-primary/20 border-primary/50 text-primary"
                                    : "bg-muted/20 border-border/30 text-muted-foreground hover:border-border/60"
                                }`}
                              >
                                {p.label}
                              </button>
                            ))}
                          </div>
                        </div>

                        {/* Live summary */}
                        <div className="rounded-xl bg-muted/20 border border-border/30 px-3 py-2.5 flex items-center justify-between">
                          <span className="text-xs text-muted-foreground font-mono">Total LEDs</span>
                          <span className="text-sm font-bold text-primary font-mono">
                            {gridW * gridH}
                          </span>
                        </div>
                      </div>
                    )}

                    <button
                      type="submit"
                      className="w-full py-2.5 rounded-xl bg-primary text-primary-foreground text-sm font-semibold font-mono hover:shadow-[0_0_20px_hsl(187_80%_55%/0.3)] transition-all"
                    >
                      Save Settings
                    </button>
                  </form>
                </motion.div>
              </div>
            )}
      <motion.p
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.2 }}
        className="text-muted-foreground text-sm mb-10 font-mono"
      >
        emotion-driven fabric patterns
      </motion.p>

      {/* Config Card */}
      <motion.div
        initial={{ y: 30, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.3, duration: 0.6 }}
        className="glass-card gradient-border p-8 w-full max-w-lg space-y-7"
      >
        <h2 className="text-lg font-semibold text-foreground">Configure Session</h2>

        {/* Age */}
        <div className="space-y-2">
          <label className="text-sm text-muted-foreground font-mono">Age</label>
          <input
            type="number"
            min={1}
            max={120}
            placeholder="Enter your age"
            value={config.age}
            onChange={(e) => setConfig({ ...config, age: e.target.value })}
            className="w-full bg-muted/50 border border-border/50 rounded-xl px-4 py-3 text-foreground placeholder:text-muted-foreground/50 focus:outline-none focus:ring-2 focus:ring-primary/40 transition-all"
          />
        </div>

        {/* Gender */}
        <div className="space-y-2">
          <label className="text-sm text-muted-foreground font-mono">Gender</label>
          <div className="grid grid-cols-2 gap-2">
            {genders.map((g) => (
              <button
                key={g}
                onClick={() => setConfig({ ...config, gender: g })}
                className={`px-4 py-2.5 rounded-xl text-sm transition-all border ${
                  config.gender === g
                    ? "bg-primary/15 border-primary/50 text-primary"
                    : "bg-muted/30 border-border/30 text-muted-foreground hover:border-border/60"
                }`}
              >
                {g}
              </button>
            ))}
          </div>
        </div>

        {/* Pattern Type */}
        <div className="space-y-2">
          <label className="text-sm text-muted-foreground font-mono">Pattern Type</label>
          <div className="grid grid-cols-2 gap-3">
            {patternTypes.map((p) => (
              <button
                key={p.id}
                onClick={() => setConfig({ ...config, patternType: p.id })}
                className={`rounded-xl p-4 text-left transition-all border ${
                  config.patternType === p.id
                    ? "bg-primary/10 border-primary/50"
                    : "bg-muted/20 border-border/30 hover:border-border/60"
                }`}
              >
                <PatternPreview type={p.id} active={config.patternType === p.id} />
                <span className={`text-sm font-medium block mt-2 ${config.patternType === p.id ? "text-primary" : "text-foreground"}`}>
                  {p.label}
                </span>
                <span className="text-xs text-muted-foreground">{p.desc}</span>
              </button>
            ))}
          </div>
        </div>

        {/* LED Grid Size */}
        <div className="space-y-3">
          <div className="flex justify-between items-center">
            <label className="text-sm text-muted-foreground font-mono">LED Grid Size</label>
            {config.gridSize !== "fit" && (
              <span className="text-xs font-mono text-primary">
                {resolveGrid(config.gridSize).w * resolveGrid(config.gridSize).h} LEDs
              </span>
            )}
          </div>
          <div className="grid grid-cols-5 gap-2">
            {GRID_PRESETS.map((preset) => {
              const active = config.gridSize === preset.id;
              const ledCount = preset.id !== "fit"
                ? preset.w * preset.h
                : null;
              return (
                <button
                  key={preset.id}
                  type="button"
                  onClick={() => setConfig({ ...config, gridSize: preset.id })}
                  className={`relative flex flex-col items-center justify-center gap-1.5 rounded-xl py-3 px-1 border transition-all ${
                    active
                      ? "bg-primary/10 border-primary/60 shadow-[0_0_12px_hsl(187_80%_55%/0.2)]"
                      : "bg-muted/20 border-border/30 hover:border-border/60"
                  }`}
                >
                  {/* Mini grid preview */}
                  <GridPreview size={preset.id} active={active} />
                  <span className={`text-xs font-mono font-semibold leading-none ${active ? "text-primary" : "text-foreground"}`}>
                    {preset.label}
                  </span>
                  {ledCount !== null && (
                    <span className="text-[10px] font-mono text-muted-foreground leading-none">
                      {ledCount >= 1000 ? `${(ledCount / 1000).toFixed(1)}k` : ledCount}
                    </span>
                  )}
                </button>
              );
            })}
          </div>
        </div>

        {/* Sensitivity */}
        <div className="space-y-3">
          <div className="flex justify-between items-center">
            <label className="text-sm text-muted-foreground font-mono">Signal Sensitivity</label>
            <span className="text-xs font-mono text-primary">{config.sensitivity}%</span>
          </div>
          <input
            type="range"
            min={0}
            max={100}
            value={config.sensitivity}
            onChange={(e) => setConfig({ ...config, sensitivity: Number(e.target.value) })}
            className="w-full accent-primary h-1.5 bg-muted rounded-full appearance-none cursor-pointer [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-4 [&::-webkit-slider-thumb]:h-4 [&::-webkit-slider-thumb]:bg-primary [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:shadow-[0_0_10px_hsl(187_80%_55%/0.5)]"
          />
          <div className="flex justify-between text-xs text-muted-foreground font-mono">
            <span>Low noise</span>
            <span>High detail</span>
          </div>
        </div>

        {/* Start */}
        <button
          disabled={!isValid}
          onClick={handleStartSession}
          className="w-full py-3.5 rounded-xl font-semibold text-sm flex items-center justify-center gap-2 transition-all disabled:opacity-30 disabled:cursor-not-allowed bg-primary text-primary-foreground hover:shadow-[0_0_30px_hsl(187_80%_55%/0.3)]"
        >
          Start Session
          <ChevronRight className="w-4 h-4" />
        </button>
      </motion.div>
    </motion.div>
  );
};

// ── Grid dot-matrix preview (SVG) ────────────────────────────────────────────
const GridPreview = ({ size, active }: { size: GridSize; active: boolean }) => {
  const color = active ? "hsl(187 80% 55%)" : "hsl(220 15% 30%)";
  const glowColor = active ? "hsl(187 80% 55% / 0.5)" : "transparent";

  if (size === "fit") {
    // Show an expand/arrows icon
    return (
      <svg viewBox="0 0 32 32" width="32" height="32">
        <rect width="32" height="32" fill="none" />
        {/* corner arrows */}
        <polyline points="2,10 2,2 10,2"   fill="none" stroke={color} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
        <polyline points="22,2 30,2 30,10"  fill="none" stroke={color} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
        <polyline points="30,22 30,30 22,30" fill="none" stroke={color} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
        <polyline points="10,30 2,30 2,22"  fill="none" stroke={color} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    );
  }

  // Dot-grid — show up to 6×6 dots regardless of actual count, scale fill
  const cols = size === "8x8" ? 4 : size === "16x16" ? 5 : 6;
  const rows = cols;
  const step = 32 / (cols + 1);
  const r    = size === "64x64" ? 1.4 : size === "32x32" ? 1.8 : size === "16x16" ? 2.2 : 2.8;

  const dots: { cx: number; cy: number; lit: boolean }[] = [];
  for (let row = 0; row < rows; row++) {
    for (let col = 0; col < cols; col++) {
      // Randomly (but deterministically) light ~60% of dots for visual interest
      const lit = ((row * cols + col) * 7 + row * 3) % 10 < 6;
      dots.push({ cx: step * (col + 1), cy: step * (row + 1), lit });
    }
  }

  return (
    <svg viewBox="0 0 32 32" width="32" height="32">
      <defs>
        <filter id={`glow-${size}`} x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="1.5" result="blur" />
          <feMerge><feMergeNode in="blur" /><feMergeNode in="SourceGraphic" /></feMerge>
        </filter>
      </defs>
      {dots.map(({ cx, cy, lit }, i) => (
        <circle
          key={i}
          cx={cx} cy={cy} r={r}
          fill={lit ? color : "hsl(220 15% 18%)"}
          filter={lit && active ? `url(#glow-${size})` : undefined}
          opacity={lit ? 1 : 0.5}
        />
      ))}
      {active && (
        <rect x="1" y="1" width="30" height="30" rx="4"
          fill="none" stroke={glowColor} strokeWidth="1" opacity="0.4" />
      )}
    </svg>
  );
};

const PatternPreview = ({ type, active }: { type: string; active: boolean }) => {
  const color = active ? "hsl(187 80% 55%)" : "hsl(220 15% 35%)";
  return (
    <svg viewBox="0 0 60 40" className="w-full h-10 rounded-lg overflow-hidden">
      <rect width="60" height="40" fill="hsl(230 20% 11%)" />
      {type === "organic" && (
        <>
          <circle cx="15" cy="20" r="12" fill="none" stroke={color} strokeWidth="0.8" opacity="0.6" />
          <circle cx="35" cy="15" r="8" fill="none" stroke={color} strokeWidth="0.8" opacity="0.4" />
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
          {[0, 10, 20, 30, 40, 50].map((x) => (
            <line key={`v${x}`} x1={x} y1="0" x2={x} y2="40" stroke={color} strokeWidth="0.5" opacity="0.3" />
          ))}
          {[0, 10, 20, 30].map((y) => (
            <line key={`h${y}`} x1="0" y1={y} x2="60" y2={y} stroke={color} strokeWidth="0.5" opacity="0.3" />
          ))}
        </>
      )}
    </svg>
  );
};

export default ConfigurationScreen;
