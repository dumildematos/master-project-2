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
  if (e == "calm")     return 149;
  if (e == "relaxed")  return 123;
  if (e == "focused")  return 153;
  if (e == "excited")  return 232;
  if (e == "stressed") return 0;
  return 96;
}

void paletteFromEmotion(const String& emotion) {
  if (emotion == "calm") {
    state.primary   = hexToRgb("#4F6D7A");
    state.secondary = hexToRgb("#A6C8D8");
    state.accent    = hexToRgb("#E6F1F5");
    state.shadow    = hexToRgb("#2E4057");
    return;
  }
  if (emotion == "focused") {
    state.primary   = hexToRgb("#3A86FF");
    state.secondary = hexToRgb("#4361EE");
    state.accent    = hexToRgb("#4CC9F0");
    state.shadow    = hexToRgb("#1D3557");
    return;
  }
  if (emotion == "relaxed") {
    state.primary   = hexToRgb("#A8DADC");
    state.secondary = hexToRgb("#F1FAEE");
    state.accent    = hexToRgb("#B7E4C7");
    state.shadow    = hexToRgb("#52B788");
    return;
  }
  if (emotion == "excited") {
    state.primary   = hexToRgb("#FF006E");
    state.secondary = hexToRgb("#FB5607");
    state.accent    = hexToRgb("#FFBE0B");
    state.shadow    = hexToRgb("#FF7F51");
    return;
  }
  if (emotion == "stressed") {
    state.primary   = hexToRgb("#6A040F");
    state.secondary = hexToRgb("#9D0208");
    state.accent    = hexToRgb("#D00000");
    state.shadow    = hexToRgb("#370617");
    return;
  }
  // neutral / unknown
  state.primary   = CHSV(96,  220, 255);
  state.secondary = CHSV(114, 180, 220);
  state.accent    = CHSV(132, 150, 210);
  state.shadow    = scaleC(CHSV(224, 120, 80), 60);
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
  if (state.emotion == "focused")  return "geometric";
  if (state.emotion == "stressed" || state.emotion == "excited") return "pulse";
  if (state.emotion == "calm"     || state.emotion == "relaxed") return "fluid";
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
//  PATTERN 1 — FLUID WAVES  (calm / relaxed)
// =============================================================================

void patternFluidWaves() {
  float speed = effSpeed();
  float scale = effScale();
  uint32_t t  = millis();

  for (uint8_t y = 0; y < MATRIX_H; y++) {
    for (uint8_t x = 0; x < MATRIX_W; x++) {
      float nx = (float)x / (MATRIX_W - 1);
      float ny = (float)y / (MATRIX_H - 1);

      float w1 = sinf(nx * scale * 6.28f + t * 0.001f  * speed);
      float w2 = sinf(ny * scale * 6.28f + t * 0.0008f * speed);
      float w3 = sinf((nx + ny) * scale * 4.5f + t * 0.0006f * speed);
      float v  = ((w1 + w2 + w3) / 3.0f + 1.0f) * 0.5f;

      CRGB c = blendF(state.primary, state.secondary, v);
      c += scaleC(state.accent, (uint8_t)(40 + v * 80));
      leds[XY(x, y)] = scaleC(c, (uint8_t)(90 + v * 150));
    }
  }
}

// =============================================================================
//  PATTERN 2 — GEOMETRIC RINGS  (focused)
// =============================================================================

void patternGeometric() {
  float cx    = (MATRIX_W - 1) * 0.5f;
  float cy    = (MATRIX_H - 1) * 0.5f;
  float t     = millis() * 0.001f * effSpeed();
  float rings = effRings();

  for (uint8_t y = 0; y < MATRIX_H; y++) {
    for (uint8_t x = 0; x < MATRIX_W; x++) {
      float dx  = (x - cx) / (MATRIX_W * 0.5f);
      float dy  = (y - cy) / (MATRIX_H * 0.5f);
      float r   = sqrtf(dx * dx + dy * dy);
      float ang = atan2f(dy, dx);

      if (r > 1.05f) { leds[XY(x, y)] = state.shadow; continue; }

      float v = (sinf(r * rings - t * 2.0f + ang * 2.0f) + 1.0f) * 0.5f;
      CRGB c  = blendF(state.primary, state.accent, v);
      if (v > 0.65f) c += scaleC(state.secondary, (uint8_t)(v * 100));
      leds[XY(x, y)] = scaleC(c, (uint8_t)(40 + v * 200));
    }
  }
}

// =============================================================================
//  PATTERN 3 — RHYTHMIC PULSE  (stressed / excited)
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
//  PATTERN 4 — STAR FIELD  (neutral / creative)
// =============================================================================

struct Star { uint8_t x, y, phase, speed; };
static const uint8_t NUM_STARS = 32;
Star stars[NUM_STARS];

void initStars() {
  randomSeed(analogRead(0));
  for (uint8_t i = 0; i < NUM_STARS; i++) {
    stars[i] = { (uint8_t)random(MATRIX_W), (uint8_t)random(MATRIX_H),
                 (uint8_t)random(256), (uint8_t)(random(4) + 1) };
  }
}

void patternStarField() {
  fadeToBlackBy(leds, NUM_LEDS, 40);

  uint32_t t = millis() >> 4;
  // Star density: AI complexity drives it; fallback uses alpha band
  uint8_t visible = state.aiActive
      ? (uint8_t)(8 + state.aiComplexity * 22.0f)
      : (uint8_t)(8 + state.alpha * 22.0f);
  visible = min(visible, NUM_STARS);

  // Twinkle speed: AI speed drives the tick divider; fallback is fixed
  uint8_t tick = state.aiActive
      ? (uint8_t)(t * (uint8_t)(1 + state.aiSpeed * 3.0f))
      : (uint8_t)t;

  for (uint8_t i = 0; i < visible; i++) {
    uint8_t bri = sin8(tick * stars[i].speed + stars[i].phase);
    float   mix = (float)(i % 8) / 7.0f;
    CRGB    c   = scaleC(blendF(state.primary, state.accent, mix), bri);

    leds[XY(stars[i].x, stars[i].y)] |= c;

    if (bri > 160) {
      CRGB glow = scaleC(state.secondary, bri >> 2);
      uint8_t sx = stars[i].x, sy = stars[i].y;
      if (sx > 0)             leds[XY(sx-1, sy  )] |= glow;
      if (sx < MATRIX_W - 1) leds[XY(sx+1, sy  )] |= glow;
      if (sy > 0)             leds[XY(sx,   sy-1)] |= glow;
      if (sy < MATRIX_H - 1) leds[XY(sx,   sy+1)] |= glow;
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
  if      (state.pattern == "fluid")      patternFluidWaves();
  else if (state.pattern == "geometric")  patternGeometric();
  else if (state.pattern == "pulse"   ||
           state.pattern == "textile")    patternRhythmicPulse();
  else if (state.pattern == "stars"   ||
           state.pattern == "organic")    patternStarField();
  else {
    // Unknown pattern — emotion-based fallback
    if      (state.emotion == "calm"     || state.emotion == "relaxed") patternFluidWaves();
    else if (state.emotion == "focused")                                 patternGeometric();
    else if (state.emotion == "stressed" || state.emotion == "excited") patternRhythmicPulse();
    else                                                                  patternStarField();
  }

  applyEmotionGrade();
  FastLED.setBrightness(frameBrightness());
  FastLED.show();
}

// =============================================================================
//  WEBSOCKET EVENT
// =============================================================================

void onWsEvent(WStype_t type, uint8_t* payload, size_t length) {
  switch (type) {

    case WStype_CONNECTED:
      Serial.printf("[WS]  Connected → ws://%s:%d%s\n", WS_HOST, WS_PORT, WS_PATH);
      break;

    case WStype_DISCONNECTED:
      Serial.println("[WS]  Disconnected — waiting to reconnect…");
      state.hasData   = false;
      state.active    = false;
      state.aiActive  = false;
      break;

    case WStype_TEXT: {
      // 2 kB document — enough for EEG frame + ai_pattern object
      StaticJsonDocument<2048> doc;
      DeserializationError err = deserializeJson(doc, payload, length);
      if (err) {
        Serial.printf("[WS]  JSON error: %s\n", err.c_str());
        return;
      }

      // Skip keepalive / waiting frames
      const char* frameType = doc["type"]   | "";
      const char* status    = doc["status"] | "";
      if (strcmp(frameType, "heartbeat") == 0 || strcmp(status, "waiting") == 0) return;

      // ── EEG bands ─────────────────────────────────────────────────────────
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

        // Pattern type comes from Claude
        const char* apt = aiP["pattern_type"] | nullptr;
        state.pattern = (apt && strlen(apt)) ? String(apt) : "fluid";

        Serial.printf(
          "[AI]  pattern=%-9s  speed=%.2f  complexity=%.2f  intensity=%.2f  "
          "primary=%s\n",
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
          "[EEG] %-9s  pattern=%-9s  α=%.2f β=%.2f θ=%.2f γ=%.2f  Q=%.0f  "
          "conf=%.2f  [static]\n",
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

  initStars();
  paletteFromEmotion("neutral");

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
  if (now - lastFrameMs >= FRAME_MS) {
    lastFrameMs = now;
    renderFrame();
  }
}
