export type EmotionKey = "calm" | "focused" | "relaxed" | "excited" | "stressed" | "neutral";

type EmotionMeta = {
  key: EmotionKey;
  label: string;
  hue: number;
  color: string;
  colorClass: string;
  guidance: string;
};

const EMOTION_META: Record<EmotionKey, EmotionMeta> = {
  calm: {
    key: "calm",
    label: "CALM",
    hue: 210,
    color: "hsl(187 80% 55%)",
    colorClass: "glow-text-cyan",
    guidance: "You're calm. Maintain this state to deepen the flowing visuals.",
  },
  focused: {
    key: "focused",
    label: "FOCUSED",
    hue: 40,
    color: "hsl(220 70% 55%)",
    colorClass: "text-yellow-400",
    guidance: "High focus detected. The garment sharpens and becomes structured.",
  },
  relaxed: {
    key: "relaxed",
    label: "RELAXED",
    hue: 180,
    color: "hsl(270 60% 55%)",
    colorClass: "glow-text-purple",
    guidance: "Gentle state detected. Soft, slow forms are emerging.",
  },
  excited: {
    key: "excited",
    label: "EXCITED",
    hue: 30,
    color: "hsl(310 60% 55%)",
    colorClass: "glow-text-magenta",
    guidance: "Excitement detected. Dynamic, vibrant patterns are forming.",
  },
  stressed: {
    key: "stressed",
    label: "STRESSED",
    hue: 0,
    color: "hsl(0 80% 58%)",
    colorClass: "glow-text-magenta",
    guidance: "Try to relax - take a slow breath to soften the visuals.",
  },
  neutral: {
    key: "neutral",
    label: "NEUTRAL",
    hue: 120,
    color: "hsl(140 60% 50%)",
    colorClass: "text-green-400",
    guidance: "Keep exploring your mental state to influence the design.",
  },
};

export function normalizeEmotionKey(value: unknown): EmotionKey {
  if (typeof value !== "string") {
    return "neutral";
  }

  const normalized = value.trim().toLowerCase();
  return normalized in EMOTION_META ? (normalized as EmotionKey) : "neutral";
}

export function getEmotionMeta(value: unknown): EmotionMeta {
  return EMOTION_META[normalizeEmotionKey(value)];
}

export function formatEmotionLabel(value: unknown): string {
  const meta = getEmotionMeta(value);
  return `${meta.label.charAt(0)}${meta.label.slice(1).toLowerCase()}`;
}