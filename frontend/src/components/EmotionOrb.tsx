import React from "react";
import { motion, AnimatePresence } from "framer-motion";
import { getEmotionMeta } from "../lib/emotionMeta";

interface Props {
  emotion:    string;
  confidence: number;
  colorHue:   number;
}

export default function EmotionOrb({ emotion, confidence, colorHue }: Props) {
  const meta = getEmotionMeta(emotion);
  const h    = colorHue;

  return (
    <div className="flex flex-col items-center gap-6">
      {/* Orb */}
      <div className="relative flex items-center justify-center">
        {/* Outer glow ring */}
        <motion.div
          className="absolute rounded-full"
          style={{
            width: 180, height: 180,
            background: `radial-gradient(circle, hsl(${h}, 70%, 55%) 0%, transparent 70%)`,
            opacity: 0.15,
          }}
          animate={{ scale: [1, 1.15, 1] }}
          transition={{ duration: 3, repeat: Infinity, ease: "easeInOut" }}
        />

        {/* Rotating gradient ring */}
        <motion.div
          className="absolute rounded-full"
          style={{
            width: 148, height: 148,
            background: `conic-gradient(from 0deg, hsl(${h}, 80%, 55%), hsl(${(h + 60) % 360}, 70%, 60%), hsl(${(h + 120) % 360}, 80%, 55%), transparent)`,
            borderRadius: "50%",
            padding: 2,
          }}
          animate={{ rotate: 360 }}
          transition={{ duration: 8, repeat: Infinity, ease: "linear" }}
        />

        {/* Core orb */}
        <motion.div
          className="relative rounded-full flex items-center justify-center"
          style={{
            width: 120, height: 120,
            background: `radial-gradient(circle at 35% 35%, hsl(${h}, 80%, 70%), hsl(${h}, 70%, 40%))`,
            boxShadow: `0 0 40px hsl(${h}, 80%, 50% / 0.6), 0 0 80px hsl(${h}, 70%, 45% / 0.3)`,
          }}
          animate={{ scale: [1, 1.04, 1] }}
          transition={{ duration: 2, repeat: Infinity, ease: "easeInOut" }}
        >
          {/* Inner highlight */}
          <div
            className="absolute rounded-full opacity-40"
            style={{ width: 40, height: 40, top: 18, left: 22,
              background: `radial-gradient(circle, white, transparent)` }}
          />
        </motion.div>
      </div>

      {/* Emotion label */}
      <AnimatePresence mode="wait">
        <motion.div
          key={emotion}
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -6 }}
          transition={{ duration: 0.4 }}
          className="text-center"
        >
          <p className={`text-3xl font-bold tracking-[0.2em] ${meta.colorClass}`}>
            {meta.label}
          </p>
          <p className="mono text-xs text-muted-foreground mt-1">
            {Math.round(confidence * 100)}% confidence
          </p>
        </motion.div>
      </AnimatePresence>

      {/* Confidence bar */}
      <div className="w-full max-w-[200px]">
        <div className="h-1 rounded-full bg-muted overflow-hidden">
          <motion.div
            className="h-full rounded-full"
            style={{ background: `hsl(${h}, 80%, 55%)` }}
            animate={{ width: `${confidence * 100}%` }}
            transition={{ duration: 0.6, ease: "easeOut" }}
          />
        </div>
      </div>
    </div>
  );
}
