import React from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Activity, ArrowLeft, CircleHelp, Sliders, Radio } from "lucide-react";
import { useWebSocket }          from "../hooks/useWebSocket";
import { useManualMode }         from "../hooks/useManualMode";
import { useDisconnectDetector } from "../hooks/useDisconnectDetector";
import { resolveApiBaseUrl } from "../lib/runtimeConfig";
import EmotionOrb     from "./EmotionOrb";
import EEGChart       from "./EEGChart";
import BandCards      from "./BandCards";
import DesignParams   from "./DesignParams";
import GuidancePanel  from "./GuidancePanel";
import ManualModePanel from "./ManualModePanel";
import DisconnectModal, { ReconnectToast } from "./DisconnectModal";
import type { SessionConfig } from "../types";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "./ui/tooltip";

const formatVitalValue = (value: number | null, digits = 1) =>
  value === null ? "--" : value.toFixed(digits);

const getVitalStatus = (source: string | null, heartBpm: number | null) => {
  if (heartBpm !== null) {
    return source === "bluemuse-ppg" ? "BlueMuse PPG" : source ?? "Live pulse stream";
  }

  if (source === null) {
    return "No pulse stream";
  }

  return `${source} detected`;
};

function SliderInfo({ text }: { text: string }) {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <button
          type="button"
          className="text-muted-foreground transition-colors hover:text-primary"
          aria-label="More information"
        >
          <CircleHelp className="h-3.5 w-3.5" />
        </button>
      </TooltipTrigger>
      <TooltipContent side="top" className="max-w-xs text-xs leading-relaxed">
        {text}
      </TooltipContent>
    </Tooltip>
  );
}

interface Props {
  config:  SessionConfig;
  setConfig: React.Dispatch<React.SetStateAction<SessionConfig>>;
  onBack:  () => void;
}

export default function MonitoringScreen({ config, setConfig, onBack }: Props) {
  // ── Live data ───────────────────────────────────────────────────────────────
  const { data, connected, hasSignal, history, emotionHistory } = useWebSocket();
  const [isUpdatingSensitivity, setIsUpdatingSensitivity] = React.useState(false);
  const [isUpdatingSmoothing, setIsUpdatingSmoothing] = React.useState(false);
  const updateTimeoutRef = React.useRef<number | null>(null);
  const smoothingUpdateTimeoutRef = React.useRef<number | null>(null);

  // ── Manual mode ─────────────────────────────────────────────────────────────
  const manual = useManualMode();

  function handleToggleManual() {
    if (manual.isManual) {
      manual.deactivate();
    } else {
      manual.activate(data);  // snapshot live values into sliders
    }
  }

  // ── Disconnect detection ────────────────────────────────────────────────────
  const { isDisconnected, showReconnectToast, dismiss } = useDisconnectDetector({
    connected,
    hasSignal,
    signal_quality: data.signal_quality,
    isManualMode:   manual.isManual,
  });

  // ── Decide which data to render ─────────────────────────────────────────────
  const display = manual.isManual ? manual.manualData : data;
  const vitalStatus = getVitalStatus(
    display.vitals.source,
    display.vitals.heartBpm,
  );

  const handleSensitivityChange = React.useCallback((value: number) => {
    setConfig((previous) => ({ ...previous, sensitivity: value }));

    if (updateTimeoutRef.current !== null) {
      window.clearTimeout(updateTimeoutRef.current);
    }

    updateTimeoutRef.current = window.setTimeout(async () => {
      setIsUpdatingSensitivity(true);
      try {
        await fetch(`${resolveApiBaseUrl()}/api/session/sensitivity`, {
          method: "PATCH",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ sensitivity: value / 100 }),
        });
      } catch {
        // Keep the slider responsive even if the backend update fails.
      } finally {
        setIsUpdatingSensitivity(false);
      }
    }, 120);
  }, [setConfig]);

  const handleSmoothingChange = React.useCallback((value: number) => {
    setConfig((previous) => ({ ...previous, smoothing: value }));

    if (smoothingUpdateTimeoutRef.current !== null) {
      window.clearTimeout(smoothingUpdateTimeoutRef.current);
    }

    smoothingUpdateTimeoutRef.current = window.setTimeout(async () => {
      setIsUpdatingSmoothing(true);
      try {
        await fetch(`${resolveApiBaseUrl()}/api/session/emotion-smoothing`, {
          method: "PATCH",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ smoothing: value / 100 }),
        });
      } catch {
        // Keep the slider responsive even if the backend update fails.
      } finally {
        setIsUpdatingSmoothing(false);
      }
    }, 120);
  }, [setConfig]);

  React.useEffect(() => {
    return () => {
      if (updateTimeoutRef.current !== null) {
        window.clearTimeout(updateTimeoutRef.current);
      }
      if (smoothingUpdateTimeoutRef.current !== null) {
        window.clearTimeout(smoothingUpdateTimeoutRef.current);
      }
    };
  }, []);

  return (
    <TooltipProvider delayDuration={150}>
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.4 }}
      className="min-h-screen bg-background neural-bg flex flex-col overflow-hidden"
    >
      {/* ── Header ──────────────────────────────────────────────────────────── */}
      <motion.header
        initial={{ opacity: 0, y: -16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        className="relative z-10 flex items-center justify-between px-8 py-5 border-b border-border/30"
      >
        {/* Left — back + brand */}
        <div className="flex items-center gap-4">
          <button
            onClick={onBack}
            className="p-2 rounded-xl border border-border/30 text-muted-foreground
              hover:text-foreground hover:border-border/60 transition-all"
          >
            <ArrowLeft className="w-4 h-4" />
          </button>
          <div className="flex items-center gap-2">
            <Activity className="w-5 h-5 glow-text-cyan animate-glow-pulse" />
            <span className="text-xl font-bold tracking-[0.25em] glow-text-cyan">SENTIO</span>
          </div>
        </div>

        {/* Centre — session info + mode toggle */}
        <div className="hidden md:flex items-center gap-3">
          {[
            { label: "Pattern",     value: config.patternType },
            { label: "Sensitivity", value: `${config.sensitivity}%` },
            { label: "Smoothing",   value: `${config.smoothing}%` },
          ].map(({ label, value }) => (
            <div key={label} className="px-3 py-1.5 rounded-full border border-border/30
              bg-muted/30 flex gap-1.5 items-center">
              <span className="mono text-[10px] text-muted-foreground uppercase">{label}</span>
              <span className="mono text-[10px] text-primary capitalize">{value}</span>
            </div>
          ))}

          {/* ── AUTO / MANUAL toggle ── */}
          <div className="flex items-center rounded-full border border-border/40
            bg-muted/20 overflow-hidden p-0.5">
            {(["AUTO", "MANUAL"] as const).map(mode => {
              const isActive = mode === "MANUAL" ? manual.isManual : !manual.isManual;
              return (
                <button
                  key={mode}
                  onClick={handleToggleManual}
                  className="relative px-4 py-1.5 rounded-full font-mono text-[10px]
                    tracking-widest transition-all duration-300"
                  style={isActive ? {
                    background: mode === "MANUAL"
                      ? "hsl(310 60% 30%)"
                      : "hsl(187 80% 28%)",
                    color: mode === "MANUAL"
                      ? "hsl(310 80% 75%)"
                      : "hsl(187 80% 75%)",
                    boxShadow: mode === "MANUAL"
                      ? "0 0 12px hsl(310 60% 55% / 0.35)"
                      : "0 0 12px hsl(187 80% 55% / 0.35)",
                  } : {
                    background: "transparent",
                    color: "hsl(var(--muted-foreground))",
                  }}
                >
                  {mode === "MANUAL" && isActive && (
                    <motion.div
                      className="absolute left-2 top-1/2 -translate-y-1/2
                        w-1.5 h-1.5 rounded-full bg-accent"
                      animate={{ opacity: [0.4, 1, 0.4] }}
                      transition={{ duration: 1.2, repeat: Infinity }}
                    />
                  )}
                  <span className={mode === "MANUAL" && isActive ? "pl-2.5" : ""}>
                    {mode}
                  </span>
                </button>
              );
            })}
          </div>
        </div>

        {/* Right — connection status */}
        <div className="flex items-center gap-2">
          {/* Manual mode badge */}
          <AnimatePresence>
            {manual.isManual && (
              <motion.div
                key="manual-badge"
                initial={{ opacity: 0, scale: 0.85 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{   opacity: 0, scale: 0.85 }}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-full
                  border border-accent/30 bg-accent/5"
              >
                <Sliders className="w-3 h-3 text-accent" />
                <span className="mono text-[10px] font-medium text-accent">MANUAL</span>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Live / Offline pill */}
          <div className={`flex items-center gap-2 px-3 py-1.5 rounded-full border ${
            isDisconnected
              ? "border-red-500/30 bg-red-500/5"
              : connected
                ? "border-green-500/30 bg-green-500/5"
                : "border-red-500/30 bg-red-500/5"
          }`}>
            <motion.div
              className={`w-1.5 h-1.5 rounded-full ${
                isDisconnected ? "bg-red-400" : connected ? "bg-green-400" : "bg-red-400"
              }`}
              animate={{ opacity: connected && !isDisconnected ? [0.4, 1, 0.4] : 1 }}
              transition={{ duration: 1.5, repeat: Infinity }}
            />
            <span className={`mono text-[10px] font-medium ${
              isDisconnected ? "text-red-400" : connected ? "text-green-400" : "text-red-400"
            }`}>
              {isDisconnected ? "DISCONNECTED" : connected ? "LIVE" : "OFFLINE"}
            </span>
          </div>
        </div>
      </motion.header>

      {/* ── Main layout ─────────────────────────────────────────────────────── */}
      <main className={`relative z-10 flex-1 grid gap-5 p-6 max-h-[calc(100vh-73px)]
        transition-all duration-300 ${
          manual.isManual
            ? "grid-cols-[300px_1fr_280px] mr-[300px]"
            : "grid-cols-[300px_1fr_280px]"
        }`}>

        {/* Left — Emotion orb */}
        <motion.aside
          initial={{ opacity: 0, x: -20 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.5, delay: 0.1 }}
          className="flex flex-col gap-5"
        >
          <div className={`glass-card gradient-border p-6 flex flex-col
            items-center justify-center flex-1 transition-all duration-500 ${
              isDisconnected ? "opacity-30 grayscale" : ""
            }`}>
            <EmotionOrb
              emotion={display.emotion}
              confidence={display.confidence}
              colorHue={display.params.colorHue}
              detectedEmotion={display.detectedEmotion}
              detectedConfidence={display.detectedConfidence}
              isUncertain={display.isUncertain}
              mindfulness={display.mindfulness}
              restfulness={display.restfulness}
              emotionHistory={emotionHistory}
            />
          </div>
          <GuidancePanel
            guidance={display.guidance}
            emotion={display.emotion}
            connected={manual.isManual ? true : connected}
            hasSignal={manual.isManual ? true : hasSignal}
          />
        </motion.aside>

        {/* Center — Charts + band cards */}
        <motion.section
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.2 }}
          className="flex flex-col gap-5"
        >
          <div className={`transition-all duration-500 ${
            isDisconnected ? "opacity-30 grayscale" : ""
          }`}>
            <EEGChart history={history} />
          </div>
          <BandCards bands={display.bands} />

          <div className="glass-card px-5 py-4 flex flex-col gap-3">
            <div className="flex items-center justify-between">
              <div>
                <div className="flex items-center gap-2">
                  <p className="mono text-[10px] text-muted-foreground uppercase tracking-widest">Live Sensitivity</p>
                  <SliderInfo text="Controls how strongly the system reacts to EEG changes. Lower values smooth out noisy fluctuations, while higher values make the visuals respond faster to small signal changes." />
                </div>
                <p className="text-sm font-medium mt-1">Adjust stream response while monitoring</p>
              </div>
              <div className="text-right">
                <p className="mono text-sm text-primary">{config.sensitivity}%</p>
                <p className="mono text-[10px] text-muted-foreground">{isUpdatingSensitivity ? "Updating..." : "Live"}</p>
              </div>
            </div>
            <input
              type="range"
              min={0}
              max={100}
              value={config.sensitivity}
              onChange={(e) => handleSensitivityChange(Number(e.target.value))}
              className="w-full h-1.5 bg-muted rounded-full appearance-none cursor-pointer accent-primary
                [&::-webkit-slider-thumb]:appearance-none
                [&::-webkit-slider-thumb]:w-4 [&::-webkit-slider-thumb]:h-4
                [&::-webkit-slider-thumb]:bg-primary [&::-webkit-slider-thumb]:rounded-full
                [&::-webkit-slider-thumb]:shadow-[0_0_10px_hsl(187_80%_55%/0.5)]"
            />
            <div className="flex justify-between text-xs text-muted-foreground mono">
              <span>Smoother</span>
              <span>More reactive</span>
            </div>
          </div>

          <div className="glass-card px-5 py-4 flex flex-col gap-3">
            <div className="flex items-center justify-between">
              <div>
                <div className="flex items-center gap-2">
                  <p className="mono text-[10px] text-muted-foreground uppercase tracking-widest">State Smoothing</p>
                  <SliderInfo text="Controls how stable the detected mental state feels over time. Lower values switch states quickly, while higher values hold onto the recent state longer before changing." />
                </div>
                <p className="text-sm font-medium mt-1">Adjust how sticky the emotion state feels</p>
              </div>
              <div className="text-right">
                <p className="mono text-sm text-primary">{config.smoothing}%</p>
                <p className="mono text-[10px] text-muted-foreground">{isUpdatingSmoothing ? "Updating..." : "Live"}</p>
              </div>
            </div>
            <input
              type="range"
              min={0}
              max={100}
              value={config.smoothing}
              onChange={(e) => handleSmoothingChange(Number(e.target.value))}
              className="w-full h-1.5 bg-muted rounded-full appearance-none cursor-pointer accent-primary
                [&::-webkit-slider-thumb]:appearance-none
                [&::-webkit-slider-thumb]:w-4 [&::-webkit-slider-thumb]:h-4
                [&::-webkit-slider-thumb]:bg-primary [&::-webkit-slider-thumb]:rounded-full
                [&::-webkit-slider-thumb]:shadow-[0_0_10px_hsl(187_80%_55%/0.5)]"
            />
            <div className="flex justify-between text-xs text-muted-foreground mono">
              <span>Reactive</span>
              <span>Stable</span>
            </div>
          </div>

          <div className="glass-card px-5 py-3 flex items-center justify-between">
            <div className="flex items-center gap-6">
              {[
                { label: "Device",      value: "Muse Headband"          },
                { label: "Protocol",    value: "LSL → WS → Arduino"     },
                { label: "AI Model",    value: "Rule-Based v1"          },
                { label: "Sensitivity", value: `${config.sensitivity}%` },
                { label: "Smoothing",   value: `${config.smoothing}%`   },
              ].map(({ label, value }) => (
                <div key={label}>
                  <p className="mono text-[10px] text-muted-foreground uppercase tracking-widest">{label}</p>
                  <p className="text-sm font-medium mt-0.5">{value}</p>
                </div>
              ))}
            </div>
            {/* Mode indicator */}
            <div className="flex items-center gap-2">
              {manual.isManual && (
                <span className="flex items-center gap-1.5 font-mono text-[9px]
                  text-accent/70 tracking-widest">
                  <Radio className="w-3 h-3" />
                  MANUAL OVERRIDE
                </span>
              )}
              <div className="mono text-[11px] text-muted-foreground">
                {new Date().toLocaleTimeString()}
              </div>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="glass-card px-5 py-4 flex items-center justify-between">
              <div>
                <p className="mono text-[10px] text-muted-foreground uppercase tracking-widest">Heart Rate</p>
                <p className="text-sm font-medium mt-1">HeartPy BPM</p>
              </div>
              <div className="text-right">
                <p className="mono text-lg text-primary">{formatVitalValue(display.vitals.heartBpm)}</p>
                <p className="mono text-[10px] text-muted-foreground">{display.vitals.heartBpm === null ? vitalStatus : "bpm"}</p>
              </div>
            </div>

            <div className="glass-card px-5 py-4 flex items-center justify-between">
              <div>
                <p className="mono text-[10px] text-muted-foreground uppercase tracking-widest">Respiration</p>
                <p className="text-sm font-medium mt-1">HeartPy breathing rate</p>
              </div>
              <div className="text-right">
                <p className="mono text-lg text-primary">{formatVitalValue(display.vitals.respirationRpm)}</p>
                <p className="mono text-[10px] text-muted-foreground">{display.vitals.respirationRpm === null ? vitalStatus : "rpm"}</p>
              </div>
            </div>
          </div>
        </motion.section>

        {/* Right — Design params + Arduino status */}
        <motion.aside
          initial={{ opacity: 0, x: 20 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.5, delay: 0.3 }}
          className="flex flex-col gap-5"
        >
          <DesignParams params={display.params} />

          <div className="glass-card p-5 flex flex-col gap-3">
            <p className="text-xs font-semibold tracking-widest text-muted-foreground uppercase">
              Arduino
            </p>
            <div className="flex flex-col gap-2">
              {[
                { label: "Device",    value: "ESP32 + WS2812B",                                    ok: true },
                { label: "Transport", value: "WebSocket",                                           ok: true },
                { label: "LEDs",      value: (connected || manual.isManual) ? "Active" : "Standby", ok: connected || manual.isManual },
                { label: "Mode",      value: manual.isManual ? "Manual Override" : "Auto / Live",   ok: true },
                { label: "Pattern",   value: config.patternType,                                    ok: true },
              ].map(({ label, value, ok }) => (
                <div key={label} className="flex justify-between items-center">
                  <span className="mono text-[11px] text-muted-foreground">{label}</span>
                  <span className={`mono text-[11px] capitalize ${ok ? "text-green-400" : "text-muted-foreground"}`}>
                    {value}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </motion.aside>
      </main>

      {/* ── Manual mode panel (slides in from right) ────────────────────────── */}
      <ManualModePanel
        isOpen={manual.isManual}
        onClose={manual.deactivate}
        emotion={manual.emotion}
        bands={manual.bands}
        onSetEmotion={manual.setEmotion}
        onSetBand={manual.setBand}
        onCommitBand={manual.commitBand}
        onReset={manual.resetToDefaults}
      />

      {/* ── Disconnect modal ─────────────────────────────────────────────────── */}
      <DisconnectModal
        isOpen={isDisconnected}
        onDismiss={dismiss}
      />

      {/* ── Reconnect toast ──────────────────────────────────────────────────── */}
      <ReconnectToast show={showReconnectToast} />
    </motion.div>
    </TooltipProvider>
  );
}
