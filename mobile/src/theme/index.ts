// Sentio design tokens — mirrors the web frontend palette
export const colors = {
  bg:      "#080c10",
  bg2:     "#0f1419",
  border:  "#1a2233",
  text:    "#e8f0fe",
  muted:   "#6b7fa3",
  cyan:    "#29d9c8",
  amber:   "#f5a623",
  magenta: "#c45aec",

  // Emotion palette
  calm:     "#4F6D7A",
  focused:  "#3A86FF",
  relaxed:  "#A8DADC",
  excited:  "#FF006E",
  stressed: "#D00000",
  neutral:  "#6b7fa3",
};

export const emotionColor: Record<string, string> = {
  calm:     "#29d9c8",
  relaxed:  "#52B788",
  focused:  "#3A86FF",
  excited:  "#FF006E",
  stressed: "#D00000",
  neutral:  "#6b7fa3",
};

export const emotionLabel: Record<string, string> = {
  calm:     "Calm",
  relaxed:  "Relaxed",
  focused:  "Focused",
  excited:  "Excited",
  stressed: "Stressed",
  neutral:  "Neutral",
};

export const spacing = {
  xs:  4,
  sm:  8,
  md:  16,
  lg:  24,
  xl:  32,
  xxl: 48,
};

export const radius = {
  sm:  8,
  md:  12,
  lg:  16,
  full: 999,
};

export const font = {
  mono: "monospace" as const,
};
