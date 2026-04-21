import React from "react";
import { motion, AnimatePresence } from "framer-motion";
import { getEmotionMeta } from "../lib/emotionMeta";
import type { EmotionHistoryEntry } from "../hooks/useWebSocket";
import { UNCERTAIN_THRESHOLD } from "../hooks/useWebSocket";

interface Props {
  emotion:            string;
  confidence:         number;
  colorHue:           number;
  detectedEmotion?:   string;
  detectedConfidence?: number;
  isUncertain?:       boolean;
  mindfulness?:       number | null;
  restfulness?:       number | null;
  emotionHistory?:    EmotionHistoryEntry[];
}

export default function EmotionOrb({
  emotion,
  confidence,
  colorHue,
  detectedEmotion,
  detectedConfidence,
  isUncertain = false,
  mindfulness = null,
  restfulness = null,
  emotionHistory = [],
}: Props) {
  const meta         = getEmotionMeta(emotion);
  const detectedMeta = getEmotionMeta(detectedEmotion ?? emotion);
  const h            = colorHue;
  const pct          = Math.round(confidence * 100);

  // Is the raw detected emotion different from the stabilised one?
  const showDetectedDiff =
    detectedEmotion !== undefined &&
    detectedEmotion !== emotion;

  return (
    <div className="flex flex-col items-center gap-5">

      {/* ── Orb ── */}
      <div className="relative flex items-center justify-center">
        {/* Outer breathing ring */}
        <motion.div
          className="absolute rounded-full"
          style={{
            width: 180, height: 180,
            background: `radial-gradient(circle, hsl(${h}, 70%, 55%) 0%, transparent 70%)`,
            opacity: isUncertain ? 0.07 : 0.15,
          }}
          animate={{ scale: [1, 1.15, 1] }}
          transition={{ duration: isUncertain ? 4 : 3, repeat: Infinity, ease: "easeInOut" }}
        />

        {/* Rotating gradient ring — dim when uncertain */}
        <motion.div
          className="absolute rounded-full"
          style={{
            width: 148, height: 148,
            background: isUncertain
              ? `conic-gradient(from 0deg, hsl(${h},30%,40%), hsl(${h},20%,30%), transparent)`
              : `conic-gradient(from 0deg, hsl(${h},80%,55%), hsl(${(h+60)%360},70%,60%), hsl(${(h+120)%360},80%,55%), transparent)`,
            borderRadius: "50%",
            padding: 2,
            opacity: isUncertain ? 0.45 : 1,
          }}
          animate={{ rotate: 360 }}
          transition={{ duration: isUncertain ? 14 : 8, repeat: Infinity, ease: "linear" }}
        />

        {/* Core orb */}
        <motion.div
          className="relative rounded-full flex items-center justify-center"
          style={{
            width: 120, height: 120,
            background: isUncertain
              ? `radial-gradient(circle at 35% 35%, hsl(${h},40%,50%), hsl(${h},30%,25%))`
              : `radial-gradient(circle at 35% 35%, hsl(${h},80%,70%), hsl(${h},70%,40%))`,
            boxShadow: isUncertain
              ? `0 0 20px hsl(${h},40%,35%/0.3)`
              : `0 0 40px hsl(${h},80%,50%/0.6), 0 0 80px hsl(${h},70%,45%/0.3)`,
          }}
          animate={{ scale: [1, 1.04, 1] }}
          transition={{ duration: isUncertain ? 3.5 : 2, repeat: Infinity, ease: "easeInOut" }}
        >
          {/* Inner highlight */}
          <div
            className="absolute rounded-full opacity-40"
            style={{ width: 40, height: 40, top: 18, left: 22,
              background: "radial-gradient(circle, white, transparent)" }}
          />

          {/* Uncertain overlay — "?" indicator */}
          {isUncertain && (
            <span
              className="text-xl font-bold font-mono"
              style={{ color: `hsl(${h},40%,65%)`, opacity: 0.7 }}
            >?</span>
          )}
        </motion.div>
      </div>

      {/* ── Emotion label ── */}
      <AnimatePresence mode="wait">
        <motion.div
          key={emotion}
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -6 }}
          transition={{ duration: 0.4 }}
          className="text-center"
        >
          <p
            className={`text-3xl font-bold tracking-[0.2em] ${isUncertain ? "opacity-60" : ""} ${meta.colorClass}`}
          >
            {meta.label}
          </p>

          <p className="mono text-xs text-muted-foreground mt-1">
            {isUncertain
              ? `${pct}% — low confidence`
              : `${pct}% confidence`}
          </p>

          {/* Detected emotion badge — shown when different from stabilised */}
          {showDetectedDiff && (
            <motion.div
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              className="mt-2 inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full border"
              style={{
                borderColor: `hsl(${detectedMeta.hue},50%,40%)`,
                background:  `hsl(${detectedMeta.hue},40%,12%)`,
              }}
            >
              <span
                className="text-[9px] font-mono tracking-widest"
                style={{ color: detectedMeta.color }}
              >
                RAW · {detectedMeta.label}
              </span>
              {detectedConfidence !== undefined && (
                <span className="text-[9px] font-mono text-muted-foreground">
                  {Math.round(detectedConfidence * 100)}%
                </span>
              )}
            </motion.div>
          )}
        </motion.div>
      </AnimatePresence>

      {/* ── Confidence bar ── */}
      <div className="w-full max-w-[200px]">
        <div className="h-1.5 rounded-full bg-muted overflow-hidden">
          <motion.div
            className="h-full rounded-full"
            style={{
              background: isUncertain
                ? `hsl(${h},40%,40%)`
                : `hsl(${h},80%,55%)`,
            }}
            animate={{ width: `${Math.max(pct, 4)}%` }}
            transition={{ duration: 0.6, ease: "easeOut" }}
          />
        </div>
        {/* Threshold marker */}
        <div
          className="relative h-0"
          style={{ left: `${UNCERTAIN_THRESHOLD * 100}%`, top: -6 }}
        >
          <div
            className="absolute w-px h-3 -translate-x-1/2"
            style={{ background: "hsl(230 20% 35%)" }}
            title={`Uncertain below ${Math.round(UNCERTAIN_THRESHOLD * 100)}%`}
          />
        </div>
      </div>

      {/* ── Mindfulness / Restfulness bars ── */}
      {(mindfulness !== null || restfulness !== null) && (
        <div className="w-full max-w-[200px] space-y-1.5">
          {mindfulness !== null && (
            <div>
              <div className="flex justify-between mb-0.5">
                <span className="text-[9px] font-mono text-muted-foreground tracking-wider">MINDFULNESS</span>
                <span className="text-[9px] font-mono text-muted-foreground">{Math.round(mindfulness * 100)}%</span>
              </div>
              <div className="h-1 rounded-full bg-muted overflow-hidden">
                <motion.div
                  className="h-full rounded-full"
                  style={{ background: "hsl(187 80% 55%)" }}
                  animate={{ width: `${Math.round(mindfulness * 100)}%` }}
                  transition={{ duration: 0.8, ease: "easeOut" }}
                />
              </div>
            </div>
          )}
          {restfulness !== null && (
            <div>
              <div className="flex justify-between mb-0.5">
                <span className="text-[9px] font-mono text-muted-foreground tracking-wider">RESTFULNESS</span>
                <span className="text-[9px] font-mono text-muted-foreground">{Math.round(restfulness * 100)}%</span>
              </div>
              <div className="h-1 rounded-full bg-muted overflow-hidden">
                <motion.div
                  className="h-full rounded-full"
                  style={{ background: "hsl(262 70% 65%)" }}
                  animate={{ width: `${Math.round(restfulness * 100)}%` }}
                  transition={{ duration: 0.8, ease: "easeOut" }}
                />
              </div>
            </div>
          )}
        </div>
      )}

      {/* ── Emotion history strip ── */}
      {emotionHistory.length > 1 && (
        <div className="w-full max-w-[200px]">
          <p className="text-[9px] font-mono text-muted-foreground tracking-widest mb-1.5">
            HISTORY
          </p>
          <div className="flex items-center gap-1 flex-wrap">
            {emotionHistory.map((entry, i) => {
              const m = getEmotionMeta(entry.emotion);
              const isLatest = i === emotionHistory.length - 1;
              return (
                <motion.div
                  key={`${entry.t}-${entry.emotion}`}
                  initial={{ scale: 0, opacity: 0 }}
                  animate={{ scale: 1, opacity: isLatest ? 1 : 0.45 + (i / emotionHistory.length) * 0.45 }}
                  title={`${m.label} · ${Math.round(entry.confidence * 100)}%`}
                  style={{
                    width:  isLatest ? 10 : 7,
                    height: isLatest ? 10 : 7,
                    borderRadius: "50%",
                    background: m.color,
                    boxShadow: isLatest ? `0 0 6px ${m.color}` : "none",
                    flexShrink: 0,
                  }}
                />
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}
