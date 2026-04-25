/**
 * EmotionRing
 * -----------
 * Animated colour ring that pulses with the current emotion confidence.
 * Uses React Native's Animated API — no extra dependencies needed.
 */
import React, { useEffect, useRef } from "react";
import { Animated, View, Text, StyleSheet } from "react-native";
import { emotionColor, emotionLabel, colors, font } from "../theme";

interface Props {
  emotion:    string;
  confidence: number;
  size?:      number;
}

export default function EmotionRing({ emotion, confidence, size = 200 }: Props) {
  const pulse = useRef(new Animated.Value(1)).current;
  const glow  = useRef(new Animated.Value(0.3)).current;
  const emoColor = emotionColor[emotion] ?? colors.muted;

  useEffect(() => {
    const speed = 800 + (1 - confidence) * 1200; // faster when confident
    const loop = Animated.loop(
      Animated.sequence([
        Animated.parallel([
          Animated.timing(pulse, { toValue: 1.06, duration: speed, useNativeDriver: true }),
          Animated.timing(glow,  { toValue: 0.9,  duration: speed, useNativeDriver: true }),
        ]),
        Animated.parallel([
          Animated.timing(pulse, { toValue: 1.0,  duration: speed, useNativeDriver: true }),
          Animated.timing(glow,  { toValue: 0.3,  duration: speed, useNativeDriver: true }),
        ]),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [emotion, confidence]);

  const ringSize  = size;
  const innerSize = size * 0.72;

  return (
    <View style={[styles.wrapper, { width: ringSize, height: ringSize }]}>
      {/* Outer glow ring */}
      <Animated.View
        style={[
          styles.ring,
          {
            width:        ringSize,
            height:       ringSize,
            borderRadius: ringSize / 2,
            borderColor:  emoColor,
            opacity:      glow,
            transform:    [{ scale: pulse }],
          },
        ]}
      />
      {/* Inner filled circle */}
      <View
        style={[
          styles.inner,
          {
            width:            innerSize,
            height:           innerSize,
            borderRadius:     innerSize / 2,
            backgroundColor:  emoColor + "1a",
            borderColor:      emoColor + "55",
          },
        ]}
      >
        <Text style={[styles.emotionText, { color: emoColor }]}>
          {emotionLabel[emotion] ?? emotion.toUpperCase()}
        </Text>
        <Text style={[styles.pctText, { color: emoColor + "bb" }]}>
          {Math.round(confidence * 100)}%
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    alignItems:     "center",
    justifyContent: "center",
  },
  ring: {
    position:  "absolute",
    borderWidth: 2,
  },
  inner: {
    alignItems:     "center",
    justifyContent: "center",
    borderWidth:    1,
  },
  emotionText: {
    fontSize:      22,
    fontWeight:    "800",
    letterSpacing: 1,
    fontFamily:    font.mono,
  },
  pctText: {
    fontSize:   14,
    fontFamily: font.mono,
    marginTop:  4,
  },
});
