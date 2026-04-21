import React from "react";
import { motion, AnimatePresence } from "framer-motion";
import { X, RotateCcw, Cpu } from "lucide-react";
import {
  EMOTION_PRESETS,
  type EmotionKey,
  type ManualBands,
} from "../hooks/useManualMode";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const EMOTIONS: { key: EmotionKey; label: string; hue: number }[] = [
  { key: "calm",     label: "CALM",   hue: 210 },
  { key: "focused",  label: "FOCUS",  hue: 40  },
  { key: "stressed", label: "STRESS", hue: 0   },
  { key: "relaxed",  label: "RELAX",  hue: 180 },
  { key: "excited",  label: "EXCITE", hue: 285 },
];

const BAND_META: { key: keyof ManualBands; sym: string; label: string; hue: number }[] = [
  { key: "alpha",      sym: "α", label: "ALPHA",  hue: 187 },
  { key: "beta",       sym: "β", label: "BETA",   hue: 310 },
  { key: "theta",      sym: "θ", label: "THETA",  hue: 270 },
  { key: "gamma",      sym: "γ", label: "GAMMA",  hue: 45  },
  { key: "delta",      sym: "δ", label: "DELTA",  hue: 220 },
  { key: "confidence", sym: "◎", label: "CONFID", hue: 187 },
];

// ---------------------------------------------------------------------------
// Sub-components
// ---------------------------------------------------------------------------
interface BandSliderProps {
  bandKey:  keyof ManualBands;
  sym:      string;
  label:    string;
  hue:      number;
  value:    number;
  onChange: (key: keyof ManualBands, v: number) => void;
  onCommit: (key: keyof ManualBands, v: number) => void;
}

function BandSlider({ bandKey, sym, label, hue, value, onChange, onCommit }: BandSliderProps) {
  const pct   = Math.round(value * 100);
  const color = `hsl(${hue}, 70%, 58%)`;

  return (
    <div className="flex items-center gap-2.5">
      <span className="w-4 text-center font-mono text-[12px] shrink-0" style={{ color }}>
        {sym}
      </span>
      <span className="w-12 font-mono text-[9px] tracking-widest text-muted-foreground shrink-0">
        {label}
      </span>
      <div className="relative flex-1 h-1.5 rounded-full bg-muted overflow-visible">
        <div
          className="absolute left-0 top-0 h-full rounded-full transition-none"
          style={{ width: `${pct}%`, background: color }}
        />
        <input
          type="range" min={0} max={100} value={pct}
          onChange={e => onChange(bandKey, Number(e.target.value) / 100)}
          onMouseUp={e => onCommit(bandKey, Number((e.target as HTMLInputElement).value) / 100)}
          onTouchEnd={e => onCommit(bandKey, Number((e.target as HTMLInputElement).value) / 100)}
          className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
          style={{ margin: 0 }}
        />
        <div
          className="absolute top-1/2 -translate-y-1/2 -translate-x-1/2 w-3 h-3
            rounded-full border-2 border-background shadow-sm pointer-events-none"
          style={{ left: `${pct}%`, background: color }}
        />
      </div>
      <span className="w-8 text-right font-mono text-[10px] shrink-0" style={{ color }}>
        {value.toFixed(2)}
      </span>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Main panel
// ---------------------------------------------------------------------------
interface Props {
  isOpen:       boolean;
  onClose:      () => void;
  emotion:      EmotionKey;
  bands:        ManualBands;
  onSetEmotion: (e: EmotionKey) => void;
  onSetBand:    (key: keyof ManualBands, v: number) => void;
  onCommitBand: (key: keyof ManualBands, v: number) => void;
  onReset:      () => void;
}

export default function ManualModePanel({
  isOpen, onClose, emotion, bands,
  onSetEmotion, onSetBand, onCommitBand, onReset,
}: Props) {
  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          key="manual-panel"
          initial={{ x: "100%", opacity: 0 }}
          animate={{ x: 0,      opacity: 1 }}
          exit={{   x: "100%",  opacity: 0 }}
          transition={{ type: "spring", stiffness: 320, damping: 32 }}
          className="fixed top-0 right-0 bottom-0 z-40 w-[300px] flex flex-col
            border-l border-border/40 backdrop-blur-2xl overflow-hidden"
          style={{ background: "hsl(230 25% 7% / 0.97)" }}
        >
          {/* Header */}
          <div className="flex items-center justify-between px-5 py-4 border-b border-border/30">
            <div>
              <p className="text-[10px] font-semibold tracking-[0.3em] text-accent/80 uppercase">
                Manual Override
              </p>
              <p className="text-xs text-muted-foreground mt-0.5">
                Streaming to Arduino via WS
              </p>
            </div>
            <button
              onClick={onClose}
              className="p-1.5 rounded-lg border border-border/30 text-muted-foreground
                hover:text-foreground hover:border-border/60 transition-all"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          </div>

          <div className="flex-1 overflow-y-auto flex flex-col gap-5 px-5 py-4
            scrollbar-thin scrollbar-thumb-border scrollbar-track-transparent">

            {/* Emotion presets */}
            <div className="flex flex-col gap-3">
              <p className="text-[9px] font-semibold tracking-[0.3em] text-muted-foreground uppercase">
                Emotion Preset
              </p>
              <div className="grid grid-cols-5 gap-1.5">
                {EMOTIONS.map(({ key, label, hue }) => {
                  const active = key === emotion;
                  return (
                    <motion.button
                      key={key}
                      onClick={() => onSetEmotion(key)}
                      whileTap={{ scale: 0.93 }}
                      className="py-2 px-1 rounded-xl text-[8.5px] font-semibold
                        tracking-wider text-center border transition-all duration-200"
                      style={active ? {
                        background:  `hsl(${hue}, 65%, 28%)`,
                        borderColor: `hsl(${hue}, 75%, 50%)`,
                        color:       `hsl(${hue}, 90%, 78%)`,
                        boxShadow:   `0 0 12px hsl(${hue} 70% 50% / 0.35)`,
                      } : {
                        background:  "transparent",
                        borderColor: "hsl(var(--border) / 0.5)",
                        color:       "hsl(var(--muted-foreground))",
                      }}
                    >
                      {label}
                    </motion.button>
                  );
                })}
              </div>
            </div>

            {/* EEG Band sliders */}
            <div className="flex flex-col gap-3">
              <p className="text-[9px] font-semibold tracking-[0.3em] text-muted-foreground uppercase">
                EEG Band Power
              </p>
              <div className="flex flex-col gap-3.5">
                {BAND_META.map(({ key, sym, label, hue }) => (
                  <BandSlider
                    key={key}
                    bandKey={key}
                    sym={sym}
                    label={label}
                    hue={hue}
                    value={bands[key]}
                    onChange={onSetBand}
                    onCommit={onCommitBand}
                  />
                ))}
              </div>
            </div>

          </div>

          {/* Footer */}
          <div className="px-5 py-3 border-t border-border/30 flex items-center justify-between">
            <button
              onClick={onReset}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg
                border border-border/30 text-muted-foreground text-[10px]
                font-mono tracking-wider hover:text-foreground
                hover:border-border/60 transition-all"
            >
              <RotateCcw className="w-3 h-3" />
              RESET
            </button>
            <div className="flex items-center gap-2 text-[10px] font-mono text-muted-foreground/60">
              <Cpu className="w-3 h-3" />
              ESP32 · WS2812B
            </div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
