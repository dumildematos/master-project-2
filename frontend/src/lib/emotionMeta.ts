export type EmotionKey =
  | "calm"
  | "focused"
  | "relaxed"
  | "excited"
  | "stressed"
  | "neutral";

type EmotionMeta = {
  key: EmotionKey;
  label: string;
  hue: number;
  /** CSS color string used for UI elements */
  color: string;
  /** Tailwind / CSS class for glow text */
  colorClass: string;
  /** Full guidance sentence shown in the panel */
  guidance: string;
  /** Short phrase shown when confidence is low */
  uncertainGuidance: string;
  /** Which EEG bands are characteristically elevated/suppressed */
  eegSignature: string;
  /** LED pattern rendered on the t-shirt for this emotion */
  ledPattern: string;
};

const EMOTION_META: Record<EmotionKey, EmotionMeta> = {
  calm: {
    key: "calm",
    label: "CALM",
    hue: 200,
    color: "hsl(200 75% 55%)",
    colorClass: "glow-text-cyan",
    guidance:
      "You're calm. Maintain this state to deepen the slow flowing visuals.",
    uncertainGuidance: "Possibly calm — signal still stabilising.",
    eegSignature: "↑ Alpha  ↓ Beta  ↓ Gamma",
    ledPattern: "Fluid Waves · steel blue",
  },
  focused: {
    key: "focused",
    label: "FOCUSED",
    hue: 220,
    color: "hsl(220 80% 62%)",
    colorClass: "text-blue-400",
    guidance:
      "High focus detected. The garment sharpens into geometric structures.",
    uncertainGuidance: "Focus fluctuating — try to hold your concentration.",
    eegSignature: "↑ Beta  ↓ Theta  ↓ Alpha",
    ledPattern: "Geometric Rings · electric blue",
  },
  relaxed: {
    key: "relaxed",
    label: "RELAXED",
    hue: 270,
    color: "hsl(270 60% 65%)",
    colorClass: "glow-text-purple",
    guidance:
      "Gentle state detected. Soft, slow forms are emerging in purple hues.",
    uncertainGuidance: "Relaxation building — stay with the breath.",
    eegSignature: "↑ Alpha  ↑ Theta  ↓ Beta",
    ledPattern: "Fluid Waves · soft purple",
  },
  excited: {
    key: "excited",
    label: "EXCITED",
    hue: 30,
    color: "hsl(30 90% 60%)",
    colorClass: "text-orange-400",
    guidance:
      "Excitement detected. Dynamic, vibrant bursts of orange and amber.",
    uncertainGuidance: "Energy rising — let it build naturally.",
    eegSignature: "↑ Gamma  ↑ Beta  ↑ Alpha",
    ledPattern: "Rhythmic Pulse · magenta → orange → amber",
  },
  stressed: {
    key: "stressed",
    label: "STRESSED",
    hue: 0,
    color: "hsl(0 80% 58%)",
    colorClass: "text-red-400",
    guidance:
      "Stress detected — try a slow breath to soften the red patterns.",
    uncertainGuidance: "Mild stress — take a moment to breathe.",
    eegSignature: "↑ Beta  ↑ Gamma  ↓ Alpha",
    ledPattern: "Rhythmic Pulse · deep crimson",
  },
  neutral: {
    key: "neutral",
    label: "NEUTRAL",
    hue: 140,
    color: "hsl(140 55% 52%)",
    colorClass: "text-green-400",
    guidance:
      "Keep exploring your mental state — the garment is ready to respond.",
    uncertainGuidance: "Calibrating — hold still for a moment.",
    eegSignature: "Balanced across all bands",
    ledPattern: "Star Field · soft white",
  },
};

export function normalizeEmotionKey(value: unknown): EmotionKey {
  if (typeof value !== "string") return "neutral";
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
