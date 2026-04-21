// =============================================================================
//  sentio_leds.ino
//  ESP32 + WS2812B 8×8 LED Grid — EEG emotion patterns for Sentio
//
//  Connects to the Sentio Python backend over WiFi via WebSocket and renders
//  one of four emotion-driven LED patterns in real time.
//
//  Required libraries  (Tools → Manage Libraries):
//    • FastLED            by Daniel Garcia
//    • arduinoWebSockets  by Markus Sattler  (search "WebSocketsClient")
//    • ArduinoJson        by Benoit Blanchon  v6.x
//
//  Board: ESP32 Dev Module  (or any ESP32 variant)
//  Configure your WiFi credentials and backend IP in config.h before flashing.
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
//  EEG STATE  (filled from every incoming WebSocket frame)
// =============================================================================

struct EegState {
  // Frequency bands (0.0 – 1.0)
  float alpha      = 0.0f;
  float beta       = 0.0f;
  float theta      = 0.0f;
  float gamma      = 0.0f;
  float delta      = 0.0f;
  // Meta
  float confidence  = 0.0f;
  float signal_q    = 0.0f;   // 0–100
  float complexity  = 0.2f;   // pattern_complexity  0–1
  // Decoded
  String  emotion   = "neutral";
  String  pattern   = "organic";
  uint8_t hue       = 96;     // FastLED hue (0–255) matching emotion
  bool    active    = false;
  bool    hasData   = false;
  // Colour palette (resolved from backend or generated from hue)
  CRGB primary   = CHSV(96,  220, 255);
  CRGB secondary = CHSV(114, 180, 220);
  CRGB accent    = CHSV(132, 150, 210);
  CRGB shadow    = CRGB(6, 10, 16);
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

// Scale a colour by 0–255 (video-corrected — black stays black)
inline CRGB scaleC(CRGB c, uint8_t amount) {
  c.nscale8_video(amount);
  return c;
}

// Blend two colours: amount 0.0 → a,  1.0 → b
inline CRGB blendF(CRGB a, CRGB b, float amount) {
  return blend(a, b, (uint8_t)constrain(amount * 255.0f, 0.0f, 255.0f));
}

// Parse a "#RRGGBB" hex string into a CRGB value
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
//  EMOTION → HUE  (maps backend emotion strings to FastLED hue 0–255)
// =============================================================================

uint8_t emotionHue(const String& e) {
  if (e == "calm")     return 140;   // ~210° cyan-blue
  if (e == "relaxed")  return 120;   // ~180° teal
  if (e == "focused")  return 28;    // ~40°  amber
  if (e == "excited")  return 200;   // ~285° magenta
  if (e == "stressed") return 0;     // 0°    red
  return 96;                         // ~140° green = neutral
}

// Set primary/secondary/accent from a single base hue (fallback palette)
void paletteFromHue(uint8_t h) {
  state.primary   = CHSV(h,       220, 255);
  state.secondary = CHSV(h + 18,  180, 220);
  state.accent    = CHSV(h + 36,  150, 210);
  state.shadow    = scaleC(CHSV(h + 128, 120, 80), 60);
}

// Apply the backend colour palette array if present, else fall back to hue
void applyPalette(JsonArrayConst palette) {
  if (palette.isNull() || palette.size() == 0) {
    paletteFromHue(state.hue);
    return;
  }
  CRGB p = hexToRgb(palette[0] | "");
  CRGB s = palette.size() > 1 ? hexToRgb(palette[1] | "") : CRGB::Black;
  CRGB a = palette.size() > 2 ? hexToRgb(palette[2] | "") : CRGB::Black;
  state.primary   = (p == CRGB::Black) ? CHSV(state.hue,      220, 255) : p;
  state.secondary = (s == CRGB::Black) ? CHSV(state.hue + 18, 180, 220) : s;
  state.accent    = (a == CRGB::Black) ? CHSV(state.hue + 36, 150, 210) : a;
  state.shadow    = scaleC(state.primary, 30);
}

// Resolve pattern type from "pattern_type" or nested "config.pattern_type"
String resolvePattern(JsonVariantConst root) {
  const char* d = root["pattern_type"] | nullptr;
  if (d && strlen(d)) return String(d);
  const char* n = root["config"]["pattern_type"] | nullptr;
  if (n && strlen(n)) return String(n);
  // Fallback: infer from emotion
  if (state.emotion == "focused")  return "geometric";
  if (state.emotion == "stressed" || state.emotion == "excited") return "textile";
  if (state.emotion == "calm"     || state.emotion == "relaxed") return "fluid";
  return "organic";
}

// =============================================================================
//  BRIGHTNESS  (combines signal quality, confidence, and band energy)
// =============================================================================

float overallIntensity() {
  float sig    = constrain(state.signal_q / 100.0f, 0.0f, 1.0f);
  float energy = constrain(
    state.alpha * 0.25f + state.beta * 0.30f +
    state.gamma * 0.25f + state.theta * 0.20f, 0.0f, 1.0f);
  return constrain(sig * 0.45f + state.confidence * 0.30f + energy * 0.25f, 0.0f, 1.0f);
}

uint8_t frameBrightness() {
  float intensity = overallIntensity();
  float bias = 0.0f;
  if (state.emotion == "calm"    || state.emotion == "relaxed") bias = -0.08f;
  if (state.emotion == "focused")                               bias =  0.05f;
  if (state.emotion == "stressed"|| state.emotion == "excited") bias =  0.12f;
  return (uint8_t)(MAX_BRIGHTNESS * constrain(intensity + bias, 0.18f, 1.0f));
}

// Tint every pixel slightly toward the emotion colour and scale by intensity
void applyEmotionGrade() {
  float tintAmount = 0.15f + overallIntensity() * 0.30f;
  CRGB tint = blendF(state.secondary, state.primary, 0.6f);
  uint8_t scale = (uint8_t)(80 + overallIntensity() * 175);
  for (uint16_t i = 0; i < NUM_LEDS; i++) {
    leds[i] = blendF(leds[i], tint, tintAmount);
    leds[i] = scaleC(leds[i], scale);
  }
}

// =============================================================================
//  PATTERN 1 — FLUID WAVES  (calm / relaxed)
//  Plasma sine-wave overlay.  Speed ∝ beta, scale ∝ alpha + complexity.
// =============================================================================

void patternFluidWaves() {
  float speed = 0.5f  + state.beta * 2.5f + state.complexity * 2.0f;
  float scale = 1.0f  + state.alpha * 1.2f + state.complexity * 1.5f;
  uint32_t t  = millis();

  for (uint8_t y = 0; y < MATRIX_H; y++) {
    for (uint8_t x = 0; x < MATRIX_W; x++) {
      float nx = (float)x / (MATRIX_W - 1);
      float ny = (float)y / (MATRIX_H - 1);

      float w1 = sinf(nx * scale * 6.28f + t * 0.001f * speed);
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
//  Rotating concentric circles.  Speed ∝ beta, ring density ∝ complexity.
// =============================================================================

void patternGeometric() {
  float cx    = (MATRIX_W - 1) * 0.5f;
  float cy    = (MATRIX_H - 1) * 0.5f;
  float t     = millis() * 0.001f * (0.5f + state.beta * 2.0f + state.complexity * 1.5f);
  float rings = 3.0f + state.alpha * 3.0f + state.complexity * 6.0f;

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
//  Expanding rings + cross arms.  Pulse rate ∝ beta.
// =============================================================================

void patternRhythmicPulse() {
  float cx    = (MATRIX_W - 1) * 0.5f;
  float cy    = (MATRIX_H - 1) * 0.5f;
  float speed = 1.0f + state.beta * 3.5f + state.complexity * 2.0f;
  uint32_t t  = millis();

  for (uint8_t y = 0; y < MATRIX_H; y++) {
    for (uint8_t x = 0; x < MATRIX_W; x++) {
      float dx   = fabsf(x - cx);
      float dy   = fabsf(y - cy);
      float dist = sqrtf(dx * dx + dy * dy);

      // Cross arms (Gaussian falloff)
      float armX = expf(-dy * dy * 0.5f);
      float armY = expf(-dx * dx * 0.5f);
      float cross = fmaxf(armX, armY);

      // Expanding ring
      float ring = (sinf(dist * 2.0f - t * 0.003f * speed) + 1.0f) * 0.5f;

      float v = cross * 0.55f + ring * 0.45f;
      CRGB c  = blendF(state.primary, state.accent, ring);
      c += scaleC(state.secondary, (uint8_t)(cross * 80));
      leds[XY(x, y)] = scaleC(c, (uint8_t)(v * 230));
    }
  }
}

// =============================================================================
//  PATTERN 4 — STAR FIELD  (neutral / organic)
//  Twinkling stars with soft glow halo.  Density ∝ alpha.
// =============================================================================

struct Star { uint8_t x, y, phase, speed; };
static const uint8_t  NUM_STARS = 32;
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

  uint32_t t       = millis() >> 4;
  uint8_t  visible = 8 + (uint8_t)(state.alpha * 22.0f);   // 8–30 stars

  for (uint8_t i = 0; i < min(visible, NUM_STARS); i++) {
    uint8_t bri  = sin8(t * stars[i].speed + stars[i].phase);
    float   mix  = (float)(i % 8) / 7.0f;
    CRGB    c    = scaleC(blendF(state.primary, state.accent, mix), bri);

    leds[XY(stars[i].x, stars[i].y)] |= c;

    // Soft cross-shaped glow halo at peak brightness
    if (bri > 160) {
      CRGB glow = scaleC(state.secondary, bri >> 2);
      uint8_t sx = stars[i].x, sy = stars[i].y;
      if (sx > 0)            leds[XY(sx-1, sy  )] |= glow;
      if (sx < MATRIX_W - 1) leds[XY(sx+1, sy  )] |= glow;
      if (sy > 0)            leds[XY(sx,   sy-1)] |= glow;
      if (sy < MATRIX_H - 1) leds[XY(sx,   sy+1)] |= glow;
    }
  }
}

// =============================================================================
//  PATTERN 0 — IDLE  (no backend / waiting for signal)
//  Slow breathing pulse in neutral blue.
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
    // No live EEG — show idle breathing pattern at fixed brightness
    FastLED.setBrightness(MAX_BRIGHTNESS / 2);
    patternIdle();
    FastLED.show();
    return;
  }

  // Route to the correct pattern
  if      (state.pattern == "fluid")      patternFluidWaves();
  else if (state.pattern == "geometric")  patternGeometric();
  else if (state.pattern == "textile")    patternRhythmicPulse();  // textile → pulse for 8×8
  else if (state.pattern == "organic")    patternStarField();
  else {
    // Emotion-based fallback when pattern string is unrecognised
    if      (state.emotion == "calm"     || state.emotion == "relaxed")  patternFluidWaves();
    else if (state.emotion == "focused")                                  patternGeometric();
    else if (state.emotion == "stressed" || state.emotion == "excited")  patternRhythmicPulse();
    else                                                                   patternStarField();
  }

  // Apply emotion-colour tint + overall intensity scale
  applyEmotionGrade();
  FastLED.setBrightness(frameBrightness());
  FastLED.show();
}

// =============================================================================
//  WEBSOCKET EVENT  (JSON parsing lives here)
// =============================================================================

void onWsEvent(WStype_t type, uint8_t* payload, size_t length) {
  switch (type) {

    // ── Connected ──────────────────────────────────────────────────────────
    case WStype_CONNECTED:
      Serial.printf("[WS]  Connected → ws://%s:%d%s\n", WS_HOST, WS_PORT, WS_PATH);
      break;

    // ── Disconnected ───────────────────────────────────────────────────────
    case WStype_DISCONNECTED:
      Serial.println("[WS]  Disconnected — waiting to reconnect…");
      state.hasData = false;
      state.active  = false;
      break;

    // ── Incoming text frame ────────────────────────────────────────────────
    case WStype_TEXT: {
      // Use a 1 kB stack document — sufficient for the Sentio frame format
      StaticJsonDocument<1024> doc;
      DeserializationError err = deserializeJson(doc, payload, length);
      if (err) {
        Serial.printf("[WS]  JSON error: %s\n", err.c_str());
        return;
      }

      // Skip keepalive heartbeat frames (no EEG data)
      const char* frameType = doc["type"] | "";
      const char* status    = doc["status"] | "";
      if (strcmp(frameType, "heartbeat") == 0 || strcmp(status, "waiting") == 0) return;

      // ── Read EEG bands ─────────────────────────────────────────────────
      state.alpha      = doc["alpha"]             | 0.0f;
      state.beta       = doc["beta"]              | 0.0f;
      state.theta      = doc["theta"]             | 0.0f;
      state.gamma      = doc["gamma"]             | 0.0f;
      state.delta      = doc["delta"]             | 0.0f;
      state.confidence = doc["confidence"]        | 0.0f;
      state.signal_q   = doc["signal_quality"]    | 0.0f;
      state.complexity = doc["pattern_complexity"] | 0.2f;
      state.active     = (int)(doc["active"] | 1) != 0;

      // ── Emotion, hue, palette, pattern ────────────────────────────────
      String emo    = doc["emotion"] | "neutral";
      state.emotion = emo;
      state.hue     = emotionHue(emo);
      state.pattern = resolvePattern(doc.as<JsonVariantConst>());
      applyPalette(doc["color_palette"].as<JsonArrayConst>());
      state.hasData = true;

      // ── Serial debug ──────────────────────────────────────────────────
      Serial.printf("[EEG] %-9s  pattern=%-9s  α=%.2f β=%.2f θ=%.2f γ=%.2f  Q=%.0f  conf=%.2f\n",
                    emo.c_str(), state.pattern.c_str(),
                    state.alpha, state.beta, state.theta, state.gamma,
                    state.signal_q, state.confidence);
      break;
    }

    default: break;
  }
}

// =============================================================================
//  WIFI CONNECT  (supports both WPA/WPA2-Personal and WPA2-Enterprise)
// =============================================================================

void connectWifi() {
  WiFi.mode(WIFI_STA);

#if WIFI_AUTH_MODE == 1
  // WPA2-Enterprise (university / corporate networks)
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
    #error "WPA2-Enterprise selected but no suitable API found. Update your ESP32 board package."
  #endif
#else
  // Standard WPA/WPA2-Personal
  Serial.printf("[WiFi] Connecting to %s\n", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
#endif

  // Pulse LEDs blue while connecting
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
  Serial.println("╔═══════════════════════════════╗");
  Serial.println("║  Sentio LED Grid  8×8          ║");
  Serial.println("╚═══════════════════════════════╝");
  Serial.printf("Compile-time grid : %u × %u  (%u LEDs)\n", MATRIX_W, MATRIX_H, NUM_LEDS);

  // ── FastLED init ─────────────────────────────────────────────────────────
  FastLED.addLeds<LED_TYPE, LED_PIN, COLOR_ORDER>(leds, NUM_LEDS)
         .setCorrection(TypicalLEDStrip);
  FastLED.setBrightness(MAX_BRIGHTNESS);
  fill_solid(leds, NUM_LEDS, CRGB::Black);
  FastLED.show();

  initStars();
  paletteFromHue(96);   // start with neutral green palette

  // ── WiFi ─────────────────────────────────────────────────────────────────
  connectWifi();

  // ── Flash green briefly on successful WiFi connection ────────────────────
  fill_solid(leds, NUM_LEDS, scaleC(CRGB::Green, 60));
  FastLED.show();
  delay(400);
  fill_solid(leds, NUM_LEDS, CRGB::Black);
  FastLED.show();

  // ── WebSocket ────────────────────────────────────────────────────────────
  ws.begin(WS_HOST, WS_PORT, WS_PATH);
  ws.onEvent(onWsEvent);
  ws.setReconnectInterval(WS_RECONNECT_MS);
  Serial.printf("[WS]  Connecting to ws://%s:%d%s\n", WS_HOST, WS_PORT, WS_PATH);
}

// =============================================================================
//  LOOP
// =============================================================================

static uint32_t lastFrameMs = 0;
static const uint32_t FRAME_MS = 1000 / TARGET_FPS;

void loop() {
  ws.loop();   // pump WebSocket (must be called every loop iteration)

  uint32_t now = millis();
  if (now - lastFrameMs >= FRAME_MS) {
    lastFrameMs = now;
    renderFrame();
  }
}
