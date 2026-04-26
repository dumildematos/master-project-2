/**
 * EmotionRing  (Ionic / CSS animation)
 * ----------------------------------------
 * Animated colour ring that pulses with the current emotion confidence.
 * Uses CSS keyframes instead of React Native's Animated API.
 */
import React, { useEffect, useRef } from "react";
import { emotionColor, emotionLabel, colors } from "../theme";

interface Props {
  emotion:    string;
  confidence: number;  // 0–1
  size?:      number;
}

export default function EmotionRing({ emotion, confidence, size = 220 }: Props) {
  const emoColor  = emotionColor[emotion.toLowerCase()] ?? colors.muted;
  const ringSize  = size;
  const innerSize = Math.round(size * 0.72);

  // Speed: faster when confident
  const speed = (0.8 + (1 - confidence) * 1.2).toFixed(2);

  const animName = `sentio-pulse-${(emoColor.replace("#", ""))}`;

  return (
    <>
      {/* Inject keyframes for this colour */}
      <style>{`
        @keyframes ${animName} {
          0%   { transform: scale(1.0); opacity: 0.3; }
          50%  { transform: scale(1.06); opacity: 0.9; }
          100% { transform: scale(1.0); opacity: 0.3; }
        }
      `}</style>

      <div style={{
        width: ringSize, height: ringSize,
        position: "relative",
        display: "flex", alignItems: "center", justifyContent: "center",
      }}>
        {/* Outer pulsing ring */}
        <div style={{
          position: "absolute",
          width: ringSize, height: ringSize,
          borderRadius: "50%",
          border: `2px solid ${emoColor}`,
          animation: `${animName} ${speed}s ease-in-out infinite`,
        }} />

        {/* Inner filled circle */}
        <div style={{
          width: innerSize, height: innerSize,
          borderRadius: "50%",
          background: `${emoColor}1a`,
          border: `1px solid ${emoColor}55`,
          display: "flex", flexDirection: "column",
          alignItems: "center", justifyContent: "center",
        }}>
          <span style={{
            fontFamily: "monospace", fontSize: 22, fontWeight: 800,
            letterSpacing: 1, color: emoColor,
          }}>
            {emotionLabel[emotion.toLowerCase()] ?? emotion.toUpperCase()}
          </span>
          <span style={{
            fontFamily: "monospace", fontSize: 14, color: `${emoColor}bb`, marginTop: 4,
          }}>
            {Math.round(confidence * 100)}%
          </span>
        </div>
      </div>
    </>
  );
}
