/* eslint-disable @typescript-eslint/no-explicit-any */
import { motion } from "framer-motion";
import { Brain, ChevronRight } from "lucide-react";
import type { SessionConfig } from "@/pages/Index";
import React from "react";
import { resolveApiBaseUrl } from "@/lib/runtimeConfig";

const patternTypes = [
  { id: "organic", label: "Organic", desc: "Flowing natural forms" },
  { id: "geometric", label: "Geometric", desc: "Structured symmetry" },
  { id: "fluid", label: "Fluid", desc: "Liquid motion patterns" },
  { id: "textile", label: "Textile", desc: "Woven fabric inspired" },
];

const genders = ["Female", "Male", "Non-binary", "Prefer not to say"];

interface Props {
  config: SessionConfig;
  setConfig: (c: SessionConfig) => void;
  onStart: () => void;
}

const ConfigurationScreen = ({ config, setConfig, onStart }: Props) => {
    const [showDevicePopup, setShowDevicePopup] = React.useState(false);
    const [macAddress, setMacAddress] = React.useState("");
  const apiBaseUrl = React.useMemo(() => resolveApiBaseUrl(), []);

    React.useEffect(() => {
      const storedMac = localStorage.getItem("muse2MacAddress");
      if (storedMac) setMacAddress(storedMac);
    }, []);

    const handleSaveMac = (e: React.FormEvent) => {
      e.preventDefault();
      localStorage.setItem("muse2MacAddress", macAddress);
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
          signal_sensitivity: config.sensitivity / 100, // Convert to 0-1 range
          emotion_smoothing: config.smoothing / 100,
          noise_control: 1,
          mac_address: macAddress || undefined, // 
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

            {/* Device MAC Address Popup */}
            {showDevicePopup && (
              <div className="fixed bottom-0 right-0 left-0 top-0 bg-black/40 z-50 flex items-end justify-end">
                <div className="bg-white rounded-xl shadow-2xl p-6 m-8 max-w-xs w-full flex flex-col gap-4">
                  <h3 className="text-lg font-semibold mb-2">Muse2 Device MAC Address</h3>
                  <form onSubmit={handleSaveMac} className="flex flex-col gap-3">
                    <input
                      type="text"
                      value={macAddress}
                      onChange={e => setMacAddress(e.target.value)}
                      placeholder="Enter MAC address"
                      className="border border-border rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary/40"
                      required
                    />
                    <button type="submit" className="bg-primary text-white rounded-lg py-2 font-semibold text-sm mt-2">Save</button>
                  </form>
                  <button className="text-xs text-muted-foreground underline mt-2 self-end" onClick={() => setShowDevicePopup(false)}>Close</button>
                </div>
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

        <div className="space-y-3">
          <div className="flex justify-between items-center">
            <label className="text-sm text-muted-foreground font-mono">State Smoothing</label>
            <span className="text-xs font-mono text-primary">{config.smoothing}%</span>
          </div>
          <input
            type="range"
            min={0}
            max={100}
            value={config.smoothing}
            onChange={(e) => setConfig({ ...config, smoothing: Number(e.target.value) })}
            className="w-full accent-primary h-1.5 bg-muted rounded-full appearance-none cursor-pointer [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-4 [&::-webkit-slider-thumb]:h-4 [&::-webkit-slider-thumb]:bg-primary [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:shadow-[0_0_10px_hsl(187_80%_55%/0.5)]"
          />
          <div className="flex justify-between text-xs text-muted-foreground font-mono">
            <span>Reactive</span>
            <span>Stable</span>
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
