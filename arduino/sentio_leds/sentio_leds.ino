// =============================================================================
//  sentio_leds.ino
//  ESP32 + WS2812B LED Garment — AI-driven emotion patterns for Sentio
//
//  Connects to the Sentio Python backend over WiFi via WebSocket and renders
//  LED patterns whose colours, animation type, speed, complexity and intensity
//  are all defined by Claude AI in real time.
//
//  Frame priority:
//    1. ai_pattern  — Claude-generated definition (pattern type + 4 colours +
//                     speed / complexity / intensity).  Used whenever present.
//    2. color_palette + pattern_type — backend static mapper fallback.
//    3. Emotion preset — hardcoded palettes when no colour data arrives.
//    4. Idle breathing — while disconnected or waiting for EEG signal.
//
//  Required libraries  (Tools → Manage Libraries):
//    • FastLED            by Daniel Garcia
//    • arduinoWebSockets  by Markus Sattler  (search "WebSocketsClient")
//    • ArduinoJson        by Benoit Blanchon  v6.x
//
//  Board: ESP32 Dev Module  (or any ESP32 variant)
//  Configure WiFi credentials and backend IP in config.h before flashing.
// =============================================================================

#include <WiFi.h>
#include <WebSocketsClient.h>
#include <ArduinoJson.h>
#include <FastLED.h>
#include <math.h>
#include <esp_wifi.h>

// WPA2-Enterprise headers — included only when needed
#if __has_include(<esp_eap_client.h>)
  #include <esp_eap_client.h>
  #define HAS_EAP_CLIENT 1
#elif __has_include(<esp_wpa2.h>)
  #include <esp_wpa2.h>
  #define HAS_LEGACY_WPA2 1
#endif

#include "config.h"

// =============================================================================
//  LED ARRAY + WEBSOCKET
// =============================================================================

CRGB          leds[NUM_LEDS];
WebSocketsClient ws;

// =============================================================================
//  EEG + AI STATE  (filled from every incoming WebSocket frame)
// =============================================================================

struct EegState {
  // ── EEG frequency bands (0.0 – 1.0) ──────────────────────────────────────
  float alpha     = 0.0f;
  float beta      = 0.0f;
  float theta     = 0.0f;
  float gamma     = 0.0f;
  float delta     = 0.0f;
  // ── Meta ──────────────────────────────────────────────────────────────────
  float confidence = 0.0f;
  float signal_q   = 0.0f;   // 0–100
  float complexity = 0.2f;   // pattern_complexity 0–1 (static mapper fallback)
  // ── Decoded state ─────────────────────────────────────────────────────────
  String emotion  = "neutral";
  String pattern  = "organic";
  uint8_t hue     = 96;
  bool    active  = false;
  bool    hasData = false;
  // ── Colour palette ────────────────────────────────────────────────────────
  CRGB primary   = CHSV(96,  220, 255);
  CRGB secondary = CHSV(114, 180, 220);
  CRGB accent    = CHSV(132, 150, 210);
  CRGB shadow    = CRGB(6, 10, 16);
  // ── AI-generated pattern overrides ───────────────────────────────────────
  //    When aiActive=true these values come from Claude and take priority
  //    over the band-power-derived animation parameters above.
  bool  aiActive     = false;
  float aiSpeed      = 0.5f;   // 0–1 animation playback speed
  float aiComplexity = 0.3f;   // 0–1 visual intricacy
  float aiIntensity  = 0.7f;   // 0–1 brightness / vividness
} state;

// =============================================================================
//  MATRIX ADDRESSING
//  Converts (x, y) → LED index, respecting serpentine wiring and Y-flip.
// =============================================================================

uint16_t XY(uint8_t x, uint8_t y) {
  x = constrain(x, 0, MATRIX_W - 1);
  y = constrain(y, 0, MATRIX_H - 1);
#if MATRIX_FLIP_Y
  y = (MATRIX_H - 1) - y;
#endif
#if MATRIX_SERPENTINE
  if (y & 1) return (uint16_t)y * MATRIX_W + (MATRIX_W - 1 - x);
#endif
  return (uint16_t)y * MATRIX_W + x;
}

// =============================================================================
//  COLOUR HELPERS
// =============================================================================

inline CRGB scaleC(CRGB c, uint8_t amount) {
  c.nscale8_video(amount);
  return c;
}

inline CRGB blendF(CRGB a, CRGB b, float amount) {
  return blend(a, b, (uint8_t)constrain(amount * 255.0f, 0.0f, 255.0f));
}

CRGB hexToRgb(const char* hex) {
  if (!hex || *hex == '\0') return CRGB::Black;
  const char* s = (*hex == '#') ? hex + 1 : hex;
  if (strlen(s) != 6) return CRGB::Black;
  char* end;
  long v = strtol(s, &end, 16);
  if (*end != '\0') return CRGB::Black;
  return CRGB((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
}

// =============================================================================
//  EMOTION → PALETTE  (static fallback when no AI palette / color_palette)
// =============================================================================

uint8_t emotionHue(const String& e) {
  if (e == "calm")     return 160;  // sky-blue
  if (e == "relaxed")  return 112;  // soft green
  if (e == "focused")  return 192;  // electric blue (distinctly deeper than calm)
  if (e == "excited")  return 240;  // hot pink
  if (e == "stressed") return 0;    // red
  return 192;                       // neutral → cool blue
}

void paletteFromEmotion(const String& emotion) {
  if (emotion == "calm") {
    // Muted, cool — deliberate contrast with the sharper focused blue
    state.primary   = hexToRgb("#4A9CBF");  // soft cerulean
    state.secondary = hexToRgb("#87C3DC");  // sky blue
    state.accent    = hexToRgb("#C8E8F4");  // pale ice blue
    state.shadow    = hexToRgb("#1E3F5C");  // deep sea
    return;
  }
  if (emotion == "focused") {
    // Sharp, electric — higher saturation than calm to signal mental clarity
    state.primary   = hexToRgb("#0077CC");  // strong electric blue
    state.secondary = hexToRgb("#00AAFF");  // bright sky blue
    state.accent    = hexToRgb("#66D9FF");  // bright cyan
    state.shadow    = hexToRgb("#002B55");  // dark navy
    return;
  }
  if (emotion == "relaxed") {
    // Soft natural greens
    state.primary   = hexToRgb("#52B788");  // medium green
    state.secondary = hexToRgb("#95D5B2");  // soft sage
    state.accent    = hexToRgb("#D8F3DC");  // pale mint
    state.shadow    = hexToRgb("#1B4332");  // dark forest
    return;
  }
  if (emotion == "excited") {
    // Vivid warm — keep as-is, already well-matched
    state.primary   = hexToRgb("#FF006E");  // hot pink
    state.secondary = hexToRgb("#FB5607");  // orange
    state.accent    = hexToRgb("#FFBE0B");  // yellow
    state.shadow    = hexToRgb("#FF7F51");  // coral
    return;
  }
  if (emotion == "stressed") {
    // Vivid reds — was too dark (near-black), LEDs would appear nearly off
    state.primary   = hexToRgb("#CC0022");  // vivid crimson
    state.secondary = hexToRgb("#FF3355");  // bright red-pink
    state.accent    = hexToRgb("#FF7700");  // urgent orange (tension)
    state.shadow    = hexToRgb("#550011");  // deep crimson
    return;
  }
  // neutral / unknown — soft lavender-blue (was yellow-green, which is not neutral)
  state.primary   = hexToRgb("#7B8FCC");
  state.secondary = hexToRgb("#A4B0D8");
  state.accent    = hexToRgb("#CBD1EE");
  state.shadow    = hexToRgb("#1E2456");
}

// Apply backend color_palette array (static mapper fallback)
void applyStaticPalette(JsonArrayConst palette) {
  if (palette.isNull() || palette.size() == 0) {
    paletteFromEmotion(state.emotion);
    return;
  }
  CRGB p  = hexToRgb(palette[0] | "");
  CRGB s  = palette.size() > 1 ? hexToRgb(palette[1] | "") : CRGB::Black;
  CRGB a  = palette.size() > 2 ? hexToRgb(palette[2] | "") : CRGB::Black;
  paletteFromEmotion(state.emotion);   // fill shadow from emotion preset first
  if (p != CRGB::Black) state.primary   = p;
  if (s != CRGB::Black) state.secondary = s;
  if (a != CRGB::Black) state.accent    = a;
  state.shadow = blendF(state.shadow, scaleC(state.primary, 30), 0.5f);
}

// Apply AI-generated palette (all four colours including shadow)
void applyAiPalette(JsonObjectConst aiP) {
  CRGB p  = hexToRgb(aiP["primary"]   | "");
  CRGB s  = hexToRgb(aiP["secondary"] | "");
  CRGB a  = hexToRgb(aiP["accent"]    | "");
  CRGB sh = hexToRgb(aiP["shadow"]    | "");
  // Only override if Claude returned a valid hex
  if (p  != CRGB::Black) state.primary   = p;
  if (s  != CRGB::Black) state.secondary = s;
  if (a  != CRGB::Black) state.accent    = a;
  if (sh != CRGB::Black) state.shadow    = sh;
}

// Resolve pattern type from static mapper fields (fallback path)
String resolveStaticPattern(JsonVariantConst root) {
  const char* d = root["pattern_type"] | nullptr;
  if (d && strlen(d)) return String(d);
  const char* n = root["config"]["pattern_type"] | nullptr;
  if (n && strlen(n)) return String(n);
  if (state.emotion == "calm")     return "fluid";
  if (state.emotion == "relaxed")  return "breathing";
  if (state.emotion == "focused")  return "geometric";
  if (state.emotion == "excited")  return "fireworks";
  if (state.emotion == "stressed") return "stress";
  return "stars";
}

// =============================================================================
//  BRIGHTNESS
// =============================================================================

float overallIntensity() {
  float sig    = constrain(state.signal_q / 100.0f, 0.0f, 1.0f);
  float energy = constrain(
    state.alpha * 0.25f + state.beta * 0.30f +
    state.gamma * 0.25f + state.theta * 0.20f, 0.0f, 1.0f);
  return constrain(sig * 0.45f + state.confidence * 0.30f + energy * 0.25f, 0.0f, 1.0f);
}

uint8_t frameBrightness() {
  // When AI pattern is active use its intensity directly
  if (state.aiActive) {
    float v = constrain(0.20f + state.aiIntensity * 0.80f, 0.20f, 1.0f);
    return (uint8_t)(MAX_BRIGHTNESS * v);
  }
  float intensity = overallIntensity();
  float bias = 0.0f;
  if (state.emotion == "calm"    || state.emotion == "relaxed") bias = -0.08f;
  if (state.emotion == "focused")                               bias =  0.05f;
  if (state.emotion == "stressed"|| state.emotion == "excited") bias =  0.12f;
  return (uint8_t)(MAX_BRIGHTNESS * constrain(intensity + bias, 0.18f, 1.0f));
}

void applyEmotionGrade() {
  float tintAmount = state.aiActive
      ? (0.10f + state.aiIntensity * 0.25f)
      : (0.15f + overallIntensity() * 0.30f);
  CRGB  tint  = blendF(state.secondary, state.primary, 0.6f);
  uint8_t scl = state.aiActive
      ? (uint8_t)(60 + state.aiIntensity * 180)
      : (uint8_t)(80 + overallIntensity() * 175);
  for (uint16_t i = 0; i < NUM_LEDS; i++) {
    leds[i] = blendF(leds[i], tint, tintAmount);
    leds[i] = scaleC(leds[i], scl);
  }
}

// =============================================================================
//  ANIMATION PARAMETER HELPERS
//  Each function returns the effective value for speed / complexity,
//  choosing the AI override when active, or deriving from EEG bands.
// =============================================================================

// Effective speed:  AI 0–1 maps to [0.3, 4.8]; bands give [0.5, 5.0]
inline float effSpeed() {
  return state.aiActive
      ? (0.30f + state.aiSpeed * 4.50f)
      : (0.50f + state.beta  * 2.50f + state.complexity * 2.00f);
}

// Effective ring count for geometric pattern
inline float effRings() {
  return state.aiActive
      ? (3.0f + state.aiComplexity * 9.0f)
      : (3.0f + state.alpha * 3.0f + state.complexity * 6.0f);
}

// Effective plasma scale for fluid waves
inline float effScale() {
  return state.aiActive
      ? (1.0f + state.aiComplexity * 2.5f)
      : (1.0f + state.alpha * 1.2f + state.complexity * 1.5f);
}

// Effective pulse speed (higher base rate for pulse pattern)
inline float effPulseSpeed() {
  return state.aiActive
      ? (1.0f + state.aiSpeed * 5.0f)
      : (1.0f + state.beta  * 3.5f + state.complexity * 2.0f);
}

// =============================================================================
//  PATTERN 1a — EXPANDING RINGS  (calm)
//  Concentric rings radiate from true centre (3.5, 3.5) and wrap continuously.
//  A second ring half a cycle behind adds depth without extra state.
//  Ported from the reference Alpha pattern; colours driven by emotion palette.
// =============================================================================

void patternFluidWaves() {
  float t_ms = (float)millis();
  float speed = effSpeed() * 0.025f;   // slow expansion for calm

  // Two rings 4 units apart so one is always visible as the other wraps
  float r1 = fmodf(t_ms * speed, 8.0f);
  float r2 = fmodf(r1 + 4.0f,   8.0f);

  fill_solid(leds, NUM_LEDS, CRGB::Black);

  for (uint8_t y = 0; y < MATRIX_H; y++) {
    for (uint8_t x = 0; x < MATRIX_W; x++) {
      float cx   = (float)x - 3.5f;
      float cy   = (float)y - 3.5f;
      float dist = sqrtf(cx * cx + cy * cy);

      // Primary ring — bright crisp edge
      float d1 = fabsf(dist - r1);
      if (d1 < 0.6f) {
        leds[XY(x, y)] = scaleC(state.primary,
                                  (uint8_t)(255.0f * (1.0f - d1 / 0.6f)));
      } else if (d1 < 1.4f) {
        leds[XY(x, y)] |= scaleC(state.secondary,
                                   (uint8_t)(70.0f * (1.0f - d1 / 1.4f)));
      }

      // Trailing accent ring
      float d2 = fabsf(dist - r2);
      if (d2 < 0.5f) {
        leds[XY(x, y)] |= scaleC(state.accent,
                                   (uint8_t)(110.0f * (1.0f - d2 / 0.5f)));
      }
    }
  }
}

// =============================================================================
//  PATTERN 1b — SCROLLING SINE WAVE  (relaxed)
//  A sine wave scrolls horizontally across the matrix with three colour tiers:
//  bright core (primary), medium band (secondary), dim halo (accent).
//  Ported from the reference Wave pattern; amplitude/speed driven by EEG.
// =============================================================================

void patternBreathing() {
  float t_ms  = (float)millis();
  float speed = effSpeed() * 0.25f;
  float phase = t_ms * 0.001f * speed;  // wave scrolls as phase grows

  fill_solid(leds, NUM_LEDS, CRGB::Black);

  for (uint8_t x = 0; x < MATRIX_W; x++) {
    // Wave centre Y for this column — amplitude 2.5 keeps wave on-screen
    float waveY = sinf(((float)x - 3.5f + phase) * 0.8f) * 2.5f + 3.5f;

    for (uint8_t y = 0; y < MATRIX_H; y++) {
      float dist = fabsf((float)y - waveY);

      if (dist < 0.7f) {
        leds[XY(x, y)] = scaleC(state.primary,
                                  (uint8_t)(255.0f * (1.0f - dist / 0.7f)));
      } else if (dist < 1.4f) {
        leds[XY(x, y)] = scaleC(state.secondary,
                                  (uint8_t)(120.0f * (1.0f - dist / 1.4f)));
      } else if (dist < 2.2f) {
        leds[XY(x, y)] = scaleC(state.accent,
                                  (uint8_t)( 40.0f * (1.0f - dist / 2.2f)));
      }
    }
  }
}

// =============================================================================
//  PATTERN 2 — GEOMETRIC RINGS + SPOKES  (focused)
//  Crisp-edged concentric rings + 8-fold rotating spokes — ordered, precise.
// =============================================================================

void patternGeometric() {
  float t     = (float)millis() * 0.001f * effSpeed();
  float rings = effRings();

  fill_solid(leds, NUM_LEDS, CRGB::Black);

  for (uint8_t y = 0; y < MATRIX_H; y++) {
    for (uint8_t x = 0; x < MATRIX_W; x++) {
      float dx = (float)x - 3.5f;
      float dy = (float)y - 3.5f;

      // Manhattan distance from true centre → diamond-shaped rings.
      // Dividing by 3.5 places the diamond boundary at the midpoints of each
      // side (pixels (3.5,0), (7,3.5), (3.5,7), (0,3.5)), clipping corners.
      float mDist = (fabsf(dx) + fabsf(dy)) / 3.5f;
      if (mDist > 1.0f) continue;  // corner pixels outside diamond → black

      float ang = atan2f(dy, dx);

      // Diamond rings using Manhattan distance (no fmodf sign issue since
      // we wrap explicitly)
      float rp = fmodf(mDist * rings - t, 1.0f);
      if (rp < 0.0f) rp += 1.0f;
      float ring_v = (rp < 0.4f) ? (rp / 0.4f)
                   : (rp < 0.6f) ? (1.0f - (rp - 0.4f) / 0.2f) : 0.0f;

      // 8-fold spokes rotating clockwise
      float spoke   = cosf(ang * 8.0f - t * 0.4f);
      float spoke_v = constrain((spoke - 0.5f) / 0.5f, 0.0f, 1.0f);

      float v = fmaxf(ring_v, spoke_v * 0.55f);
      if (v < 0.05f) continue;

      CRGB c = blendF(state.primary, state.accent, ring_v);
      c      = blendF(c, state.secondary, spoke_v * 0.5f);
      leds[XY(x, y)] = scaleC(c, (uint8_t)(v * 235));
    }
  }
}

// =============================================================================
//  PATTERN 3 — RHYTHMIC PULSE  (energetic fallback — AI "pulse" / "textile")
// =============================================================================

void patternRhythmicPulse() {
  float cx    = (MATRIX_W - 1) * 0.5f;
  float cy    = (MATRIX_H - 1) * 0.5f;
  float speed = effPulseSpeed();
  uint32_t t  = millis();

  for (uint8_t y = 0; y < MATRIX_H; y++) {
    for (uint8_t x = 0; x < MATRIX_W; x++) {
      float dx   = fabsf(x - cx);
      float dy   = fabsf(y - cy);
      float dist = sqrtf(dx * dx + dy * dy);

      float armX = expf(-dy * dy * 0.5f);
      float armY = expf(-dx * dx * 0.5f);
      float cross = fmaxf(armX, armY);

      float ring = (sinf(dist * 2.0f - t * 0.003f * speed) + 1.0f) * 0.5f;
      float v    = cross * 0.55f + ring * 0.45f;

      CRGB c = blendF(state.primary, state.accent, ring);
      c += scaleC(state.secondary, (uint8_t)(cross * 80));
      leds[XY(x, y)] = scaleC(c, (uint8_t)(v * 230));
    }
  }
}

// =============================================================================
//  PATTERN 4 — FIREWORKS BURST  (excited)
//  Colour-spark particles launched from random points; bounce off edges.
// =============================================================================

struct Particle { float x, y, vx, vy; uint8_t life, colorIdx; };
static const uint8_t NUM_PARTICLES = 20;
Particle particles[NUM_PARTICLES];
static uint32_t lastBurstMs = 0;

void initParticles() {
  for (uint8_t i = 0; i < NUM_PARTICLES; i++) particles[i].life = 0;
}

void spawnBurst(float ox, float oy) {
  uint8_t n = 3 + (uint8_t)(state.aiActive ? state.aiComplexity * 5.0f
                                            : state.gamma       * 5.0f);
  for (uint8_t b = 0; b < n; b++) {
    for (uint8_t i = 0; i < NUM_PARTICLES; i++) {
      if (particles[i].life == 0) {
        float angle = (float)random(628) * 0.01f;
        float spd   = 0.35f + (float)random(60) * 0.01f;
        particles[i] = { ox, oy, cosf(angle) * spd, sinf(angle) * spd,
                         (uint8_t)(20 + random(20)), (uint8_t)random(3) };
        break;
      }
    }
  }
}

void patternFireworks() {
  fadeToBlackBy(leds, NUM_LEDS, 55);

  uint32_t now      = millis();
  float    speed    = state.aiActive ? (0.5f + state.aiSpeed * 2.5f)
                                     : (1.0f + state.beta    * 2.0f);
  uint32_t interval = (uint32_t)(400.0f / speed);

  if (now - lastBurstMs > interval) {
    spawnBurst((float)random(MATRIX_W), (float)random(MATRIX_H));
    lastBurstMs = now;
  }

  for (uint8_t i = 0; i < NUM_PARTICLES; i++) {
    if (particles[i].life == 0) continue;
    particles[i].x   += particles[i].vx;
    particles[i].y   += particles[i].vy;
    particles[i].life--;

    if (particles[i].x < 0.0f || particles[i].x > (float)(MATRIX_W - 1)) particles[i].vx *= -0.6f;
    if (particles[i].y < 0.0f || particles[i].y > (float)(MATRIX_H - 1)) particles[i].vy *= -0.6f;
    particles[i].x = constrain(particles[i].x, 0.0f, (float)(MATRIX_W - 1));
    particles[i].y = constrain(particles[i].y, 0.0f, (float)(MATRIX_H - 1));

    uint8_t bri = (uint8_t)(particles[i].life * 6);  // life 0–39 → bri 0–234
    CRGB    c;
    switch (particles[i].colorIdx) {
      case 0:  c = scaleC(state.primary,   bri); break;
      case 1:  c = scaleC(state.secondary, bri); break;
      default: c = scaleC(state.accent,    bri); break;
    }
    leds[XY((uint8_t)particles[i].x, (uint8_t)particles[i].y)] |= c;
  }
}

// =============================================================================
//  PATTERN 5 — CHAOTIC STRESS  (stressed)
//  Four incommensurable high-freq sine waves + hard threshold — jittery, tense.
// =============================================================================

void patternStress() {
  float t     = (float)millis() * 0.001f;
  float speed = effPulseSpeed() * 1.8f;

  // Dark base so scatter dots stand out
  fill_solid(leds, NUM_LEDS, scaleC(state.shadow, 30));

  // ── Random scatter (reference Stress pattern) ────────────────────────────
  // Every frame spawns new random dots — the constant reshuffling creates
  // genuine visual chaos that raw math alone cannot replicate.
  uint8_t numDots = (uint8_t)(18.0f + (state.aiActive
      ? state.aiComplexity * 30.0f
      : state.beta         * 30.0f));
  for (uint8_t i = 0; i < numDots; i++) {
    CRGB c = (random(2) == 0) ? state.primary : state.accent;
    leds[XY(random(MATRIX_W), random(MATRIX_H))] = scaleC(c, random(80, 255));
  }

  // ── Incommensurable sine overlay ─────────────────────────────────────────
  // Four mutually-prime frequencies produce a never-repeating waveform;
  // ORed on top of the scatter so both layers are visible simultaneously.
  for (uint8_t y = 0; y < MATRIX_H; y++) {
    for (uint8_t x = 0; x < MATRIX_W; x++) {
      float n1 = sinf(x * 2.7f + t * speed * 3.1f);
      float n2 = sinf(y * 3.1f - t * speed * 2.7f);
      float n3 = sinf((x + y) * 1.9f + t * speed * 4.3f);
      float n4 = sinf((x - y) * 2.3f - t * speed * 3.7f);
      float v  = ((n1 + n2 + n3 + n4) / 4.0f + 1.0f) * 0.5f;

      if (v > 0.55f) {
        float vn = (v - 0.55f) / 0.45f;
        leds[XY(x, y)] |= scaleC(state.secondary, (uint8_t)(vn * 160.0f));
      }
    }
  }
}

// =============================================================================
//  PATTERN 6 — STAR FIELD  (neutral / creative)
// =============================================================================

// Star upgraded from reference: float brightness + delta allow smooth fade-in
// and fade-out; when a star hits 0 it relocates to a new random position and
// picks a fresh colour from the current emotion palette.
struct Star { uint8_t x, y; float brightness; float delta; CRGB color; };
static const uint8_t NUM_STARS = 16;
Star stars[NUM_STARS];

void respawnStar(uint8_t i) {
  stars[i].x          = random(MATRIX_W);
  stars[i].y          = random(MATRIX_H);
  stars[i].brightness = 0.0f;
  stars[i].delta      = (float)(random(2, 7)) / 200.0f;  // 0.01–0.035 / frame
  switch (random(3)) {
    case 0:  stars[i].color = state.primary;   break;
    case 1:  stars[i].color = state.secondary; break;
    default: stars[i].color = state.accent;    break;
  }
}

void initStars() {
  randomSeed(analogRead(0));
  for (uint8_t i = 0; i < NUM_STARS; i++) {
    // Spread evenly across the grid so the first frame is not a blank screen
    stars[i].x          = (uint8_t)((i * 5) % MATRIX_W);
    stars[i].y          = (uint8_t)((i * 3) % MATRIX_H);
    stars[i].brightness = (float)random(100) / 100.0f;   // staggered start
    stars[i].delta      = (float)(random(2, 7)) / 200.0f;
    // Colours set from current palette (call after paletteFromEmotion)
    stars[i].color      = (i % 3 == 0) ? state.primary
                        : (i % 3 == 1) ? state.secondary
                        :                state.accent;
  }
}

void patternStarField() {
  fill_solid(leds, NUM_LEDS, scaleC(state.shadow, 12));

  for (uint8_t i = 0; i < NUM_STARS; i++) {
    stars[i].brightness += stars[i].delta;

    if (stars[i].brightness >= 1.0f) {
      stars[i].brightness = 1.0f;
      stars[i].delta      = -stars[i].delta;  // start fading out
    } else if (stars[i].brightness <= 0.0f) {
      respawnStar(i);   // relocate with new colour from emotion palette
      continue;         // invisible this frame
    }

    uint8_t bri = (uint8_t)(stars[i].brightness * 255.0f);
    leds[XY(stars[i].x, stars[i].y)] |= scaleC(stars[i].color, bri);

    // Soft cross-glow for bright stars
    if (bri > 160) {
      CRGB    glow = scaleC(state.secondary, bri >> 2);
      uint8_t sx   = stars[i].x;
      uint8_t sy   = stars[i].y;
      if (sx > 0)             leds[XY(sx - 1, sy    )] |= glow;
      if (sx < MATRIX_W - 1) leds[XY(sx + 1, sy    )] |= glow;
      if (sy > 0)             leds[XY(sx,     sy - 1)] |= glow;
      if (sy < MATRIX_H - 1) leds[XY(sx,     sy + 1)] |= glow;
    }
  }
}

// =============================================================================
//  PATTERN 0 — IDLE  (disconnected / waiting for EEG signal)
// =============================================================================

void patternIdle() {
  uint8_t bri = beatsin8(6, 15, 110);
  fill_solid(leds, NUM_LEDS, scaleC(CHSV(160, 210, 255), bri));
}

// =============================================================================
//  RENDER  (called every frame)
// =============================================================================

void renderFrame() {
  if (!state.hasData || !state.active || state.signal_q < SIGNAL_THRESHOLD) {
    FastLED.setBrightness(MAX_BRIGHTNESS / 2);
    patternIdle();
    FastLED.show();
    return;
  }

  // Route to the correct pattern (pattern name set from AI or static mapper)
  if      (state.pattern == "fluid")                         patternFluidWaves();
  else if (state.pattern == "breathing")                     patternBreathing();
  else if (state.pattern == "geometric")                     patternGeometric();
  else if (state.pattern == "fireworks" ||
           state.pattern == "burst")                         patternFireworks();
  else if (state.pattern == "stress"    ||
           state.pattern == "chaos")                         patternStress();
  else if (state.pattern == "pulse"     ||
           state.pattern == "textile")                       patternRhythmicPulse();
  else if (state.pattern == "stars"     ||
           state.pattern == "organic")                       patternStarField();
  else {
    // Unknown pattern — emotion-based fallback
    if      (state.emotion == "calm")     patternFluidWaves();
    else if (state.emotion == "relaxed")  patternBreathing();
    else if (state.emotion == "focused")  patternGeometric();
    else if (state.emotion == "excited")  patternFireworks();
    else if (state.emotion == "stressed") patternStress();
    else                                  patternStarField();
  }

  applyEmotionGrade();
  FastLED.setBrightness(frameBrightness());
  FastLED.show();
}

// =============================================================================
//  EMOTION TRANSITION FLASH
//  A brief two-frame flash in the new emotion's primary colour signals the
//  garment switching states — ported from the reference flashTransition().
//  Called from loop() via a flag set in the WebSocket handler so it never
//  runs inside the WS callback (avoids re-entrancy issues).
// =============================================================================

static bool pendingEmotionFlash = false;

void flashEmotionTransition() {
  fill_solid(leds, NUM_LEDS, scaleC(state.primary, 180));
  FastLED.show();
  delay(60);
  fill_solid(leds, NUM_LEDS, CRGB::Black);
  FastLED.show();
  delay(60);
}

// =============================================================================
//  STATUS REPORTING  (Arduino → backend)
//  Sends the currently rendered emotion + pattern type so the backend and
//  mobile app can display what the garment is actually showing.
// =============================================================================

static uint32_t lastStatusMs     = 0;
static String   lastStatusEmotion = "";
static String   lastStatusPattern = "";
static const uint32_t STATUS_INTERVAL_MS  = 5000;   // periodic report every 5 s
static const uint32_t STATUS_DEBOUNCE_MS  = 500;    // min gap on change

void sendArduinoStatus() {
  char buf[192];
  snprintf(buf, sizeof(buf),
    "{\"type\":\"arduino_status\","
    "\"emotion\":\"%s\","
    "\"pattern\":\"%s\","
    "\"ai_active\":%s,"
    "\"signal_q\":%.0f,"
    "\"ts\":%lu}",
    state.emotion.c_str(),
    state.pattern.c_str(),
    state.aiActive ? "true" : "false",
    state.signal_q,
    millis()
  );

  bool sent = ws.sendTXT(buf);
  Serial.printf("[TX]  arduino_status  emotion=%-9s  pattern=%-9s  "
                "ai=%s  Q=%.0f  %s\n",
                state.emotion.c_str(),
                state.pattern.c_str(),
                state.aiActive ? "Y" : "N",
                state.signal_q,
                sent ? "OK" : "FAIL(disconnected?)");

  lastStatusEmotion = state.emotion;
  lastStatusPattern = state.pattern;
  lastStatusMs      = millis();
}

// =============================================================================
//  WEBSOCKET EVENT
// =============================================================================

void onWsEvent(WStype_t type, uint8_t* payload, size_t length) {
  switch (type) {

    case WStype_CONNECTED:
      Serial.printf("[WS]  Connected → ws://%s:%d%s\n", WS_HOST, WS_PORT, WS_PATH);
      lastStatusMs = 0;  // send status immediately on first data after reconnect
      break;

    case WStype_DISCONNECTED:
      Serial.println("[WS]  Disconnected — waiting to reconnect…");
      state.hasData     = false;
      state.active      = false;
      state.aiActive    = false;
      lastStatusEmotion = "";  // force status send as soon as data resumes
      lastStatusPattern = "";
      break;

    case WStype_TEXT: {
      // 4 kB — stream frames include a nested config object (~400 B) plus
      // ai_pattern colours/params; 2 kB was too tight and caused silent drops.
      StaticJsonDocument<4096> doc;
      DeserializationError err = deserializeJson(doc, payload, length);
      if (err) {
        Serial.printf("[WS]  JSON parse error: %s  (frame %u B)\n",
                      err.c_str(), (unsigned)length);
        return;
      }

      // Skip keepalive / waiting frames (no Serial spam for these)
      const char* frameType = doc["type"]   | "";
      const char* status    = doc["status"] | "";
      if (strcmp(frameType, "heartbeat") == 0 || strcmp(status, "waiting") == 0) return;

      // ── EEG bands ─────────────────────────────────────────────────────────
      bool   hadData    = state.hasData;
      String prevEmotion = state.emotion;

      state.alpha      = doc["alpha"]              | 0.0f;
      state.beta       = doc["beta"]               | 0.0f;
      state.theta      = doc["theta"]              | 0.0f;
      state.gamma      = doc["gamma"]              | 0.0f;
      state.delta      = doc["delta"]              | 0.0f;
      state.confidence = doc["confidence"]         | 0.0f;
      state.signal_q   = doc["signal_quality"]     | 0.0f;
      state.complexity = doc["pattern_complexity"] | 0.2f;
      state.active     = (int)(doc["active"] | 1) != 0;
      state.emotion    = doc["emotion"] | "neutral";
      state.hue        = emotionHue(state.emotion);
      state.hasData    = true;

      // Trigger a flash transition when the detected emotion changes
      if (hadData && state.emotion != prevEmotion) {
        pendingEmotionFlash = true;
      }

      // ── AI pattern (primary path) ─────────────────────────────────────────
      JsonObjectConst aiP = doc["ai_pattern"].as<JsonObjectConst>();
      if (!aiP.isNull() && aiP.containsKey("pattern_type")) {
        // Apply AI-generated colours
        applyAiPalette(aiP);

        // Apply AI animation parameters
        state.aiSpeed      = constrain(aiP["speed"]      | 0.5f, 0.0f, 1.0f);
        state.aiComplexity = constrain(aiP["complexity"] | 0.3f, 0.0f, 1.0f);
        state.aiIntensity  = constrain(aiP["intensity"]  | 0.7f, 0.0f, 1.0f);
        state.aiActive     = true;

        // Pattern type comes from Claude (or user override forwarded by backend)
        const char* apt = aiP["pattern_type"] | nullptr;
        state.pattern = (apt && strlen(apt)) ? String(apt) : "fluid";

        Serial.printf(
          "[RX]  AI     emotion=%-9s  pattern=%-9s  spd=%.2f  cplx=%.2f  "
          "bri=%.2f  primary=%s\n",
          state.emotion.c_str(),
          state.pattern.c_str(),
          state.aiSpeed, state.aiComplexity, state.aiIntensity,
          (aiP["primary"] | "#??????")
        );

      } else {
        // ── Static mapper fallback ─────────────────────────────────────────
        state.aiActive = false;
        state.pattern  = resolveStaticPattern(doc.as<JsonVariantConst>());
        applyStaticPalette(doc["color_palette"].as<JsonArrayConst>());

        Serial.printf(
          "[RX]  static emotion=%-9s  pattern=%-9s  α=%.2f β=%.2f θ=%.2f "
          "γ=%.2f  Q=%.0f  conf=%.2f\n",
          state.emotion.c_str(), state.pattern.c_str(),
          state.alpha, state.beta, state.theta, state.gamma,
          state.signal_q, state.confidence
        );
      }
      break;
    }

    default: break;
  }
}

// =============================================================================
//  WIFI CONNECT
// =============================================================================

void connectWifi() {
  WiFi.mode(WIFI_STA);

#if WIFI_AUTH_MODE == 1
  Serial.printf("[WiFi] Connecting to %s (WPA2-Enterprise)\n", WIFI_SSID);
  WiFi.begin(WIFI_SSID);
  #if defined(HAS_EAP_CLIENT)
    esp_eap_client_set_identity((const uint8_t*)WIFI_IDENTITY, strlen(WIFI_IDENTITY));
    esp_eap_client_set_username((const uint8_t*)WIFI_USERNAME, strlen(WIFI_USERNAME));
    esp_eap_client_set_password((const uint8_t*)WIFI_PASSWORD, strlen(WIFI_PASSWORD));
    esp_wifi_sta_enterprise_enable();
  #elif defined(HAS_LEGACY_WPA2)
    esp_wifi_sta_wpa2_ent_set_identity((uint8_t*)WIFI_IDENTITY, strlen(WIFI_IDENTITY));
    esp_wifi_sta_wpa2_ent_set_username((uint8_t*)WIFI_USERNAME, strlen(WIFI_USERNAME));
    esp_wifi_sta_wpa2_ent_set_password((uint8_t*)WIFI_PASSWORD, strlen(WIFI_PASSWORD));
    esp_wpa2_config_t config = WPA2_CONFIG_INIT_DEFAULT();
    esp_wifi_sta_wpa2_ent_enable(&config);
  #else
    #error "WPA2-Enterprise selected but no suitable API found."
  #endif
#else
  Serial.printf("[WiFi] Connecting to %s\n", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
#endif

  uint32_t tick = 0;
  while (WiFi.status() != WL_CONNECTED) {
    delay(300);
    Serial.print(".");
    uint8_t bri = (tick++ % 2) ? 60 : 20;
    fill_solid(leds, NUM_LEDS, scaleC(CHSV(160, 200, 255), bri));
    FastLED.show();
  }
  Serial.printf("\n[WiFi] Connected  IP=%s  RSSI=%d dBm\n",
                WiFi.localIP().toString().c_str(), WiFi.RSSI());
}

// =============================================================================
//  SETUP
// =============================================================================

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println();
  Serial.println("╔══════════════════════════════════════╗");
  Serial.println("║  Sentio LED Garment  · AI Patterns   ║");
  Serial.println("╚══════════════════════════════════════╝");
  Serial.printf("Grid: %u × %u = %u LEDs\n", MATRIX_W, MATRIX_H, NUM_LEDS);

  FastLED.addLeds<LED_TYPE, LED_PIN, COLOR_ORDER>(leds, NUM_LEDS)
         .setCorrection(TypicalLEDStrip);
  FastLED.setBrightness(MAX_BRIGHTNESS);
  fill_solid(leds, NUM_LEDS, CRGB::Black);
  FastLED.show();

  initParticles();
  paletteFromEmotion("neutral");
  initStars();   // must be after paletteFromEmotion — stars sample state.primary/secondary/accent

  connectWifi();

  fill_solid(leds, NUM_LEDS, scaleC(CRGB::Green, 60));
  FastLED.show();
  delay(400);
  fill_solid(leds, NUM_LEDS, CRGB::Black);
  FastLED.show();

  ws.begin(WS_HOST, WS_PORT, WS_PATH);
  ws.onEvent(onWsEvent);
  ws.setReconnectInterval(WS_RECONNECT_MS);
  Serial.printf("[WS]  Connecting to ws://%s:%d%s\n", WS_HOST, WS_PORT, WS_PATH);
  Serial.println("[WS]  Waiting for first AI pattern frame…");
}

// =============================================================================
//  LOOP
// =============================================================================

static uint32_t lastFrameMs = 0;
static const uint32_t FRAME_MS = 1000 / TARGET_FPS;

void loop() {
  ws.loop();
  uint32_t now = millis();

  // Fire emotion-transition flash set by the WebSocket handler (runs outside
  // the callback to avoid re-entrancy issues with FastLED.show / delay)
  if (pendingEmotionFlash) {
    pendingEmotionFlash = false;
    flashEmotionTransition();
    now = millis();   // refresh after delay so frame timing stays accurate
  }

  if (now - lastFrameMs >= FRAME_MS) {
    lastFrameMs = now;
    renderFrame();
  }

  // Send status back to the backend when emotion/pattern changes or every 5 s
  if (state.hasData) {
    bool changed = (state.emotion != lastStatusEmotion || state.pattern != lastStatusPattern);
    bool periodic = (now - lastStatusMs >= STATUS_INTERVAL_MS);
    bool debounced = (now - lastStatusMs >= STATUS_DEBOUNCE_MS);
    if ((changed && debounced) || periodic) {
      sendArduinoStatus();
    }
  }
}
