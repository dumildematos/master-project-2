// =============================================================================
//  sentio_leds.ino
//  ESP32 + WS2812B Matrix — EEG-driven LED patterns for Sentio T-shirt
//
//  Required libraries (install via Arduino Library Manager):
//    • FastLED          by Daniel Garcia          (LED control)
//    • WebSocketsClient by Markus Sattler          (arduinoWebSockets)
//    • ArduinoJson      by Benoit Blanchon  v6.x   (JSON parsing)
//
//  Board: "Adafruit Feather ESP32 V2" when available in the ESP32 boards package
//         otherwise use "ESP32 Dev Module" for classic ESP32 boards
//  If esptool reports "This chip is ESP32-S2, not ESP32", the selected COM port
//  is not the Feather ESP32 V2 or the wrong board target is selected.
//
//  Grid sizing:
//    MATRIX_W / MATRIX_H in config.h set the MAXIMUM (compile-time) grid.
//    At runtime the backend sends matrix_width / matrix_height in every
//    WebSocket frame.  The sketch applies those values immediately, so the
//    operator can resize the display from the frontend settings panel without
//    re-flashing the firmware.  Values are clamped to [1, MATRIX_W|H].
// =============================================================================

#include <WiFi.h>
#include <WebSocketsClient.h>
#include <ArduinoJson.h>
#include <FastLED.h>
#include <math.h>
#include <esp_wifi.h>
#if __has_include(<esp_eap_client.h>)
#include <esp_eap_client.h>
#define SENTIO_HAS_EAP_CLIENT 1
#elif __has_include(<esp_wpa2.h>)
#include <esp_wpa2.h>
#define SENTIO_HAS_LEGACY_WPA2 1
#endif
#include "config.h"

// =============================================================================
//  GLOBALS
// =============================================================================

CRGB leds[NUM_LEDS];          // compile-time max allocation
WebSocketsClient ws;

// ── Runtime grid dimensions (updated from every WebSocket frame) ─────────────
// Start from compile-time defaults; overwritten as soon as the first frame arrives.
uint8_t gW = MATRIX_W;        // active columns
uint8_t gH = MATRIX_H;        // active rows

// ── Live EEG state received from backend ─────────────────────────────────────
struct EegState {
  float   alpha      = 0.0f;
  float   beta       = 0.0f;
  float   theta      = 0.0f;
  float   gamma      = 0.0f;
  float   delta      = 0.0f;
  float   confidence = 0.0f;
  float   complexity = 0.2f;
  float   heartBpm    = 0.0f;
  float   heartConf   = 0.0f;
  float   signal_q   = 0.0f;   // 0–100
  uint8_t hue        = 96;     // FastLED hue (0-255), default green/neutral
  String  emotion    = "neutral";
  String  pattern    = "organic";
  bool    active     = false;
  bool    hasData    = false;
  CRGB    primary    = CHSV(96, 220, 255);
  CRGB    secondary  = CHSV(120, 180, 220);
  CRGB    accent     = CHSV(150, 180, 210);
  CRGB    shadow     = CRGB(8, 12, 18);
} state;

// Particles for the Estrelas pattern
struct Star {
  uint8_t x, y, phase, speed;
};
static const uint8_t NUM_STARS = 48;
Star stars[NUM_STARS];

uint32_t lastFrameMs = 0;
const uint32_t FRAME_MS = 1000 / TARGET_FPS;

// =============================================================================
//  MATRIX ADDRESSING  (serpentine + optional vertical flip)
//  Uses runtime gW / gH — no recompile needed when grid changes.
// =============================================================================

uint16_t xy(uint8_t x, uint8_t y) {
  // Clamp to active grid
  if (x >= gW) x = gW - 1;
  if (y >= gH) y = gH - 1;

#if MATRIX_FLIP_Y
  y = (gH - 1) - y;
#endif

#if MATRIX_SERPENTINE
  if (y & 1) {
    return (uint16_t)y * gW + (gW - 1 - x);
  }
#endif
  return (uint16_t)y * gW + x;
}

// =============================================================================
//  GRID HELPERS
// =============================================================================

// Number of LEDs currently active
inline uint16_t numLeds() { return (uint16_t)gW * gH; }

// Black-out LEDs that fall outside the active grid so they never show stale
// data when the grid shrinks at runtime.
void clearInactiveLeds() {
  uint16_t active = numLeds();
  if (active < NUM_LEDS) {
    fill_solid(leds + active, NUM_LEDS - active, CRGB::Black);
  }
}

// Apply a new grid size received from the backend.
// Values are clamped to the physical hardware max (MATRIX_W × MATRIX_H).
// Re-randomises stars so they stay within the new bounds.
void applyGridSize(uint8_t newW, uint8_t newH) {
  uint8_t clampedW = constrain(newW, 1, MATRIX_W);
  uint8_t clampedH = constrain(newH, 1, MATRIX_H);
  if (clampedW == gW && clampedH == gH) return;  // no change — skip redraw

  if (newW > MATRIX_W || newH > MATRIX_H) {
    Serial.printf("[GRID] Requested %u x %u exceeds hardware max %u x %u — clamped\n",
                  newW, newH, MATRIX_W, MATRIX_H);
  }
  gW = clampedW;
  gH = clampedH;
  Serial.printf("[GRID] Active grid: %u x %u  (%u LEDs)\n", gW, gH, numLeds());

  // Re-scatter stars within new bounds
  for (uint8_t i = 0; i < NUM_STARS; i++) {
    stars[i].x = random(gW);
    stars[i].y = random(gH);
  }
  // Clear entire buffer so pixels outside the new grid don't linger
  fill_solid(leds, NUM_LEDS, CRGB::Black);
  FastLED.show();
}

// =============================================================================
//  EMOTION → HUE MAPPING
// =============================================================================

uint8_t emotionToHue(const String& emotion) {
  if (emotion == "calm")     return 140;  // cyan-blue  (~210°)
  if (emotion == "relaxed")  return 120;  // teal       (~180°)
  if (emotion == "focused")  return 28;   // amber-gold (~40°)
  if (emotion == "excited")  return 200;  // magenta    (~285°)
  if (emotion == "stressed") return 0;    // red        (0°)
  return 96;                              // green      (~140°) = neutral
}

CRGB parseHexColor(const char* hex) {
  if (hex == nullptr) return CRGB::Black;

  const char* value = hex;
  if (*value == '#') value++;
  if (strlen(value) != 6) return CRGB::Black;

  char* endPtr = nullptr;
  long raw = strtol(value, &endPtr, 16);
  if (endPtr == nullptr || *endPtr != '\0') return CRGB::Black;

  return CRGB((raw >> 16) & 0xFF, (raw >> 8) & 0xFF, raw & 0xFF);
}

CRGB scaleColor(const CRGB& color, uint8_t amount) {
  CRGB scaled = color;
  scaled.nscale8_video(amount);
  return scaled;
}

CRGB mixColors(const CRGB& from, const CRGB& to, float amount) {
  amount = constrain(amount, 0.0f, 1.0f);
  return blend(from, to, (uint8_t)(amount * 255.0f));
}

float bandEnergy() {
  return constrain(
    state.alpha * 0.22f +
    state.beta  * 0.30f +
    state.gamma * 0.24f +
    state.theta * 0.16f +
    state.delta * 0.08f,
    0.0f,
    1.0f
  );
}

float mindIntensity() {
  float signal = constrain(state.signal_q / 100.0f, 0.0f, 1.0f);
  float energy = bandEnergy();
  float heart = constrain(state.heartConf, 0.0f, 1.0f);
  return constrain(signal * 0.40f + state.confidence * 0.30f + energy * 0.15f + heart * 0.15f, 0.0f, 1.0f);
}

float heartPulseFactor() {
  if (state.heartBpm < 40.0f || state.heartConf <= 0.0f) {
    return 1.0f;
  }

  uint8_t pulse = beatsin8((uint8_t)constrain(state.heartBpm, 40.0f, 180.0f), 160, 255);
  float amount = constrain(state.heartConf, 0.0f, 1.0f);
  return 0.80f + ((pulse / 255.0f) * 0.20f * amount);
}

CRGB mindStateColor() {
  float calmWeight = constrain(state.alpha * 0.7f + state.theta * 0.3f, 0.0f, 1.0f);
  float focusWeight = constrain(state.beta * 0.75f + state.confidence * 0.25f, 0.0f, 1.0f);
  float exciteWeight = constrain(state.gamma * 0.8f + state.beta * 0.2f, 0.0f, 1.0f);

  CRGB calmColor = mixColors(state.secondary, state.primary, calmWeight);
  CRGB activeColor = mixColors(state.primary, state.accent, constrain(focusWeight + exciteWeight * 0.4f, 0.0f, 1.0f));

  if (state.emotion == "calm" || state.emotion == "relaxed") {
    return mixColors(calmColor, state.primary, 0.65f);
  }
  if (state.emotion == "focused") {
    return mixColors(state.primary, state.accent, 0.35f + focusWeight * 0.4f);
  }
  if (state.emotion == "stressed" || state.emotion == "excited") {
    return mixColors(activeColor, state.accent, 0.55f + exciteWeight * 0.3f);
  }
  return mixColors(calmColor, activeColor, 0.5f);
}

void applyMindStateGrade() {
  float intensity = mindIntensity();
  float tintAmount = 0.18f + intensity * 0.34f;
  CRGB tint = mindStateColor();
  float pulse = heartPulseFactor();
  uint16_t active = numLeds();

  for (uint16_t index = 0; index < active; index++) {
    leds[index] = mixColors(leds[index], tint, tintAmount);
    leds[index] = scaleColor(leds[index], (uint8_t)((70 + intensity * 185) * pulse));
  }
}

uint8_t resolveBrightness() {
  float intensity = mindIntensity();
  float emotionBias = 0.0f;

  if (state.emotion == "calm" || state.emotion == "relaxed") emotionBias = -0.08f;
  if (state.emotion == "focused") emotionBias = 0.06f;
  if (state.emotion == "stressed" || state.emotion == "excited") emotionBias = 0.12f;

  float value = constrain(intensity + emotionBias, 0.18f, 1.0f);
  value = constrain(value * heartPulseFactor(), 0.18f, 1.0f);
  return (uint8_t)(MAX_BRIGHTNESS * value);
}

void setFallbackPalette(const String& emotion) {
  uint8_t baseHue = emotionToHue(emotion);
  state.primary   = CHSV(baseHue,      220, 255);
  state.secondary = CHSV(baseHue + 18, 180, 220);
  state.accent    = CHSV(baseHue + 36, 150, 210);
  state.shadow    = scaleColor(CHSV(baseHue + 96, 120, 80), 70);
}

void applyPalette(JsonArrayConst palette) {
  if (palette.isNull() || palette.size() == 0) {
    setFallbackPalette(state.emotion);
    return;
  }

  CRGB primary   = parseHexColor(palette[0] | "");
  CRGB secondary = parseHexColor(palette.size() > 1 ? (palette[1] | "") : "");
  CRGB accent    = parseHexColor(palette.size() > 2 ? (palette[2] | "") : "");
  CRGB shadow    = parseHexColor(palette.size() > 3 ? (palette[3] | "") : "");

  state.primary   = primary   == CRGB::Black ? CHSV(state.hue,      220, 255) : primary;
  state.secondary = secondary == CRGB::Black ? CHSV(state.hue + 18, 180, 220) : secondary;
  state.accent    = accent    == CRGB::Black ? CHSV(state.hue + 36, 150, 210) : accent;
  state.shadow    = shadow    == CRGB::Black ? scaleColor(state.primary, 40)  : scaleColor(shadow, 96);
}

String resolvePattern(JsonVariantConst root) {
  const char* direct = root["pattern_type"] | nullptr;
  if (direct != nullptr && strlen(direct) > 0) return String(direct);

  const char* nested = root["config"]["pattern_type"] | nullptr;
  if (nested != nullptr && strlen(nested) > 0) return String(nested);

  if (state.emotion == "focused") return "geometric";
  if (state.emotion == "stressed" || state.emotion == "excited") return "textile";
  if (state.emotion == "calm" || state.emotion == "relaxed") return "fluid";
  return "organic";
}

uint8_t resolveGridValue(JsonVariantConst root, const char* key, uint8_t fallback) {
  if (!root[key].isNull()) {
    return (uint8_t)(root[key] | (int)fallback);
  }
  if (!root["config"][key].isNull()) {
    return (uint8_t)(root["config"][key] | (int)fallback);
  }
  return fallback;
}

float resolveFloat(JsonVariantConst root, const char* key, float fallback) {
  if (!root[key].isNull()) {
    return root[key] | fallback;
  }
  if (!root["config"][key].isNull()) {
    return root["config"][key] | fallback;
  }
  return fallback;
}

void beginWifiConnection() {
#if WIFI_AUTH_MODE == 1
  WiFi.begin(WIFI_SSID);

  #if defined(SENTIO_HAS_EAP_CLIENT)
    esp_eap_client_set_identity((const uint8_t*)WIFI_IDENTITY, strlen(WIFI_IDENTITY));
    esp_eap_client_set_username((const uint8_t*)WIFI_USERNAME, strlen(WIFI_USERNAME));
    esp_eap_client_set_password((const uint8_t*)WIFI_PASSWORD, strlen(WIFI_PASSWORD));
    esp_wifi_sta_enterprise_enable();
  #elif defined(SENTIO_HAS_LEGACY_WPA2)
    esp_wifi_sta_wpa2_ent_set_identity((uint8_t*)WIFI_IDENTITY, strlen(WIFI_IDENTITY));
    esp_wifi_sta_wpa2_ent_set_username((uint8_t*)WIFI_USERNAME, strlen(WIFI_USERNAME));
    esp_wifi_sta_wpa2_ent_set_password((uint8_t*)WIFI_PASSWORD, strlen(WIFI_PASSWORD));
    esp_wpa2_config_t config = WPA2_CONFIG_INIT_DEFAULT();
    esp_wifi_sta_wpa2_ent_enable(&config);
  #else
    #error "This ESP32 core does not expose WPA2-Enterprise APIs. Use a core with esp_eap_client.h or esp_wpa2.h support."
  #endif
#else
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
#endif
}

const char* wifiAuthModeLabel() {
#if WIFI_AUTH_MODE == 1
  return "WPA2-Enterprise";
#else
  return "WPA/WPA2 Personal";
#endif
}

// =============================================================================
//  PATTERN 1 — ONDAS FLUIDAS  (calm / relaxed)
//  Plasma sine-wave overlay; speed ∝ beta, scale ∝ alpha
// =============================================================================

void patternFluidWaves() {
  float speed = 0.45f + state.beta * 2.4f + state.complexity * 1.8f;
  float scale = 0.9f + state.alpha * 1.1f + state.complexity * 1.4f;
  uint32_t t  = millis();

  for (uint8_t y = 0; y < gH; y++) {
    for (uint8_t x = 0; x < gW; x++) {
      float nx = (float)x / gW;
      float ny = (float)y / gH;

      float w1 = sinf(nx * scale * 6.28f + t * 0.001f * speed);
      float w2 = sinf(ny * scale * 6.28f + t * 0.0008f * speed);
      float w3 = sinf((nx + ny) * scale * 4.5f + t * 0.0006f * speed);
      float v = ((w1 + w2 + w3) / 3.0f + 1.0f) * 0.5f;
      CRGB color = mixColors(state.primary, state.secondary, v);
      color += scaleColor(state.accent, (uint8_t)(40 + v * 80));
      leds[xy(x, y)] = scaleColor(color, (uint8_t)(90 + v * 150));
    }
  }
}

void patternOrganic() {
  float speed = 0.30f + state.alpha * 1.6f + state.complexity * 2.2f;
  float scale = 2.5f + state.complexity * 5.0f;
  uint32_t t = millis();

  for (uint8_t y = 0; y < gH; y++) {
    for (uint8_t x = 0; x < gW; x++) {
      float nx = (float)x / gW;
      float ny = (float)y / gH;
      float swirl = sinf((nx * scale + t * 0.0004f * speed) * 6.28f);
      float drift = cosf((ny * scale - t * 0.0003f * speed) * 6.28f);
      float bloom = sinf(((nx + ny) * (scale * 0.7f)) * 6.28f + t * 0.0005f * speed);
      float mix = ((swirl + drift + bloom) / 3.0f + 1.0f) * 0.5f;

      CRGB color = mixColors(state.shadow, state.primary, mix);
      color = mixColors(color, state.accent, constrain(state.gamma * 0.8f, 0.0f, 1.0f));
      leds[xy(x, y)] = scaleColor(color, (uint8_t)(45 + mix * 180));
    }
  }
}

// =============================================================================
//  PATTERN 2 — PADRÃO GEOMÉTRICO  (focused)
//  Rotating concentric rings; rotation speed ∝ beta, ring count ∝ alpha
// =============================================================================

void patternGeometric() {
  float cx    = (gW - 1) * 0.5f;
  float cy    = (gH - 1) * 0.5f;
  float t     = millis() * 0.001f * (0.4f + state.beta * 1.8f + state.complexity * 1.4f);
  float rings = 4.0f + state.alpha * 4.0f + state.complexity * 6.0f;

  for (uint8_t y = 0; y < gH; y++) {
    for (uint8_t x = 0; x < gW; x++) {
      float dx  = (x - cx) / (gW * 0.5f);
      float dy  = (y - cy) / (gH * 0.5f);
      float r   = sqrtf(dx * dx + dy * dy);
      float ang = atan2f(dy, dx);

      float v = sinf(r * rings - t * 2.0f + ang * 2.0f);
      v = (v + 1.0f) * 0.5f;

      if (r >= 1.05f) {
        leds[xy(x, y)] = state.shadow;
        continue;
      }

      CRGB color = mixColors(state.primary, state.accent, v);
      if (v > 0.65f) {
        color += scaleColor(state.secondary, (uint8_t)(v * 110));
      }
      leds[xy(x, y)] = scaleColor(color, (uint8_t)(40 + v * 200));
    }
  }
}

void patternTextile() {
  float speed = 0.20f + state.beta * 1.4f + state.complexity * 1.5f;
  float warpFreq = 4.0f + state.complexity * 10.0f;
  float weftFreq = 3.0f + state.alpha * 5.0f + state.complexity * 4.0f;
  uint32_t t = millis();

  for (uint8_t y = 0; y < gH; y++) {
    for (uint8_t x = 0; x < gW; x++) {
      float nx = (float)x / gW;
      float ny = (float)y / gH;
      float warp = (sinf(nx * warpFreq * 6.28f + t * 0.0008f * speed) + 1.0f) * 0.5f;
      float weft = (cosf(ny * weftFreq * 6.28f - t * 0.0006f * speed) + 1.0f) * 0.5f;
      bool over = ((x + y) & 1) == 0;

      CRGB threadA = mixColors(state.primary, state.secondary, warp);
      CRGB threadB = mixColors(state.shadow, state.accent, weft);
      CRGB color = over ? mixColors(threadA, threadB, 0.35f) : mixColors(threadB, threadA, 0.35f);
      float sheen = (warp * 0.55f) + (weft * 0.45f);
      leds[xy(x, y)] = scaleColor(color, (uint8_t)(55 + sheen * 180));
    }
  }
}

// =============================================================================
//  PATTERN 3 — PULSOS RÍTMICOS  (stressed / excited)
//  Cross arms + expanding ring pulses; pulse rate ∝ beta
// =============================================================================

void patternRhythmicPulse() {
  float cx    = (gW - 1) * 0.5f;
  float cy    = (gH - 1) * 0.5f;
  float speed = 0.8f + state.beta * 3.2f + state.complexity * 2.0f;
  uint32_t t  = millis();

  for (uint8_t y = 0; y < gH; y++) {
    for (uint8_t x = 0; x < gW; x++) {
      float dx = fabsf(x - cx);
      float dy = fabsf(y - cy);

      float armV = expf(-dx * dx * 0.35f);
      float armH = expf(-dy * dy * 0.35f);
      float cross = fmaxf(armV, armH);

      float dist = sqrtf(dx * dx + dy * dy);
      float ring = sinf(dist * 1.6f - t * 0.003f * speed);
      ring = (ring + 1.0f) * 0.5f;

      float v = cross * 0.55f + ring * 0.45f;
      CRGB color = mixColors(state.primary, state.accent, ring);
      color += scaleColor(state.secondary, (uint8_t)(cross * 90));
      leds[xy(x, y)] = scaleColor(color, (uint8_t)(v * 230));
    }
  }
}

// =============================================================================
//  PATTERN 4 — ESTRELAS E PARTÍCULAS  (neutral / low signal)
//  Independently twinkling stars; density ∝ alpha
// =============================================================================

void initStars() {
  randomSeed(analogRead(0));
  for (uint8_t i = 0; i < NUM_STARS; i++) {
    stars[i] = {
      (uint8_t)random(gW),
      (uint8_t)random(gH),
      (uint8_t)random(256),
      (uint8_t)(random(4) + 1)
    };
  }
}

void patternStars() {
  fadeToBlackBy(leds, numLeds(), 35);

  uint32_t t       = millis() >> 4;
  uint8_t  visible = 10 + (uint8_t)(state.alpha * 36.0f);

  for (uint8_t i = 0; i < min(visible, NUM_STARS); i++) {
    uint8_t bri = sin8(t * stars[i].speed + stars[i].phase);
    float amount = (float)(i % 12) / 11.0f;
    CRGB    c    = scaleColor(mixColors(state.primary, state.accent, amount), bri);

    leds[xy(stars[i].x, stars[i].y)] |= c;
    if (bri > 180) {
      uint8_t nx = stars[i].x, ny = stars[i].y;
      CRGB glow = scaleColor(state.secondary, bri >> 2);
      if (nx > 0)        leds[xy(nx-1, ny)] |= glow;
      if (nx < gW - 1)   leds[xy(nx+1, ny)] |= glow;
      if (ny > 0)        leds[xy(nx, ny-1)] |= glow;
      if (ny < gH - 1)   leds[xy(nx, ny+1)] |= glow;
    }
  }
}

// =============================================================================
//  PATTERN 0 — IDLE / WAITING  (no backend connection or signal too weak)
//  Slow breathing pulse in neutral blue; shown until real EEG arrives
// =============================================================================

void patternIdle() {
  uint8_t bri = beatsin8(6, 20, 120);
  fill_solid(leds, numLeds(), scaleColor(CHSV(160, 200, 255), bri));
}

// =============================================================================
//  PATTERN ROUTER
// =============================================================================

void renderFrame() {
  if (!state.hasData || !state.active || state.signal_q < SIGNAL_THRESHOLD) {
    FastLED.setBrightness(MAX_BRIGHTNESS);
    patternIdle();
  } else {
    if      (state.pattern == "fluid")      patternFluidWaves();
    else if (state.pattern == "geometric")  patternGeometric();
    else if (state.pattern == "textile")    patternTextile();
    else if (state.pattern == "organic")    patternOrganic();
    else if (state.emotion == "stressed" || state.emotion == "excited")
                                              patternRhythmicPulse();
    else                                      patternStars();

    applyMindStateGrade();
    FastLED.setBrightness(resolveBrightness());
  }

  // Always black-out LEDs outside the active grid
  clearInactiveLeds();
}

// =============================================================================
//  WEBSOCKET  —  receive + parse EEG frames
// =============================================================================

void onWsEvent(WStype_t type, uint8_t* payload, size_t length) {
  switch (type) {

    case WStype_CONNECTED:
      Serial.println("[WS]  Connected to Sentio backend");
      break;

    case WStype_DISCONNECTED:
      Serial.println("[WS]  Disconnected — retrying…");
      state.hasData = false;
      state.active = false;
      break;

    case WStype_TEXT: {
      StaticJsonDocument<1536> doc;
      DeserializationError err = deserializeJson(doc, payload, length);
      if (err) {
        Serial.print("[WS]  JSON error: ");
        Serial.println(err.c_str());
        return;
      }

      // Skip heartbeat control frames
      if (doc["type"] == "heartbeat") return;

      // ── EEG bands ────────────────────────────────────────────────────────
      state.alpha      = doc["alpha"]          | 0.0f;
      state.beta       = doc["beta"]           | 0.0f;
      state.theta      = doc["theta"]          | 0.0f;
      state.gamma      = doc["gamma"]          | 0.0f;
      state.delta      = doc["delta"]          | 0.0f;
      state.confidence = doc["confidence"]     | 0.0f;
      state.signal_q   = doc["signal_quality"] | 0.0f;
      state.complexity = resolveFloat(doc.as<JsonVariantConst>(), "pattern_complexity", 0.2f);
      state.heartBpm   = doc["heart_bpm"]      | 0.0f;
      state.heartConf  = doc["heart_confidence"] | 0.0f;
      state.active     = (doc["active"] | 1) != 0;

      String emo    = doc["emotion"] | "neutral";
      state.emotion = emo;
      state.hue     = emotionToHue(emo);
      state.pattern = resolvePattern(doc.as<JsonVariantConst>());
      applyPalette(doc["color_palette"].as<JsonArrayConst>());
      state.hasData = true;

      // ── Grid dimensions (set by operator in frontend settings) ────────────
      JsonVariantConst root = doc.as<JsonVariantConst>();
      uint8_t newW = resolveGridValue(root, "matrix_width", MATRIX_W);
      uint8_t newH = resolveGridValue(root, "matrix_height", MATRIX_H);
      applyGridSize(newW, newH);

      Serial.printf("[EEG] %-8s  pattern=%-9s α=%.2f β=%.2f θ=%.2f C=%.2f HR=%.1f Q=%.0f grid=%ux%u\n",
                    emo.c_str(),
                    state.pattern.c_str(),
            state.alpha, state.beta, state.theta, state.complexity, state.heartBpm, state.signal_q,
                    gW, gH);
      break;
    }

    default:
      break;
  }
}

// =============================================================================
//  SETUP
// =============================================================================

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("\n=== Sentio LED T-shirt ===");
  Serial.printf("Max grid: %u x %u  (%u LEDs)\n", MATRIX_W, MATRIX_H, NUM_LEDS);

  // ── FastLED ──────────────────────────────────────────────────────────────
  FastLED.addLeds<LED_TYPE, LED_PIN, COLOR_ORDER>(leds, NUM_LEDS)
         .setCorrection(TypicalLEDStrip);
  FastLED.setBrightness(MAX_BRIGHTNESS);
  fill_solid(leds, NUM_LEDS, CRGB::Black);
  FastLED.show();

  initStars();
  setFallbackPalette(state.emotion);

  // ── WiFi ─────────────────────────────────────────────────────────────────
  Serial.printf("[WiFi] Connecting to %s (%s)", WIFI_SSID, wifiAuthModeLabel());
  WiFi.mode(WIFI_STA);
  beginWifiConnection();
  while (WiFi.status() != WL_CONNECTED) {
    delay(400);
    Serial.print(".");
    FastLED.setBrightness(beatsin8(8, 10, 80));
    fill_solid(leds, NUM_LEDS, CHSV(160, 200, 80));
    FastLED.show();
  }
  Serial.printf("\n[WiFi] Connected  IP=%s\n", WiFi.localIP().toString().c_str());
  FastLED.setBrightness(MAX_BRIGHTNESS);

  // ── WebSocket ────────────────────────────────────────────────────────────
  ws.begin(WS_HOST, WS_PORT, WS_PATH);
  ws.onEvent(onWsEvent);
  ws.setReconnectInterval(WS_RECONNECT_MS);
  Serial.printf("[WS]  Connecting to ws://%s:%d%s\n", WS_HOST, WS_PORT, WS_PATH);
}

// =============================================================================
//  LOOP
// =============================================================================

void loop() {
  ws.loop();

  uint32_t now = millis();
  if (now - lastFrameMs >= FRAME_MS) {
    lastFrameMs = now;
    renderFrame();
    FastLED.show();
  }
}
