// =============================================================================
//  sentio_leds.ino
//  ESP32 + WS2812B Matrix — EEG-driven LED patterns for Sentio T-shirt
//
//  Required libraries (install via Arduino Library Manager):
//    • FastLED          by Daniel Garcia          (LED control)
//    • WebSocketsClient by Markus Sattler          (arduinoWebSockets)
//    • ArduinoJson      by Benoit Blanchon  v6.x   (JSON parsing)
//
//  Board: "ESP32 Dev Module" (esp32 by Espressif — Boards Manager)
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
  float   signal_q   = 0.0f;   // 0–100
  uint8_t hue        = 96;     // FastLED hue (0-255), default green/neutral
  String  emotion    = "neutral";
  bool    hasData    = false;
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

// =============================================================================
//  PATTERN 1 — ONDAS FLUIDAS  (calm / relaxed)
//  Plasma sine-wave overlay; speed ∝ beta, scale ∝ alpha
// =============================================================================

void patternFluidWaves() {
  float speed = 0.6f + state.beta  * 3.0f;
  float scale = 0.7f + state.alpha * 1.4f;
  uint32_t t  = millis();

  for (uint8_t y = 0; y < gH; y++) {
    for (uint8_t x = 0; x < gW; x++) {
      float nx = (float)x / gW;
      float ny = (float)y / gH;

      float w1 = sinf(nx * scale * 6.28f + t * 0.001f * speed);
      float w2 = sinf(ny * scale * 6.28f + t * 0.0008f * speed);
      float w3 = sinf((nx + ny) * scale * 4.5f + t * 0.0006f * speed);
      float v  = (w1 + w2 + w3) / 3.0f;  // -1 … +1

      uint8_t h   = state.hue + (uint8_t)(v * 28);
      uint8_t bri = (uint8_t)(130 + v * 90);
      leds[xy(x, y)] = CHSV(h, 220, bri);
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
  float t     = millis() * 0.001f * (0.4f + state.beta * 2.0f);
  float rings = 5.0f + state.alpha * 5.0f;

  for (uint8_t y = 0; y < gH; y++) {
    for (uint8_t x = 0; x < gW; x++) {
      float dx  = (x - cx) / (gW * 0.5f);
      float dy  = (y - cy) / (gH * 0.5f);
      float r   = sqrtf(dx * dx + dy * dy);
      float ang = atan2f(dy, dx);

      float v = sinf(r * rings - t * 2.0f + ang * 2.0f);
      v = (v + 1.0f) * 0.5f;

      uint8_t bri = (r < 1.05f) ? (uint8_t)(v * 220 + 20) : 0;
      uint8_t h   = state.hue + (uint8_t)(v * 36);
      leds[xy(x, y)] = CHSV(h, 240, bri);
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
  float speed = 0.8f + state.beta * 5.0f;
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

      float v     = cross * 0.55f + ring * 0.45f;
      uint8_t h   = state.hue + (uint8_t)(ring * 22);
      uint8_t bri = (uint8_t)(v * 230);
      leds[xy(x, y)] = CHSV(h, 245, bri);
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
    uint8_t h   = state.hue + (uint8_t)(i * 5);
    CRGB    c   = CHSV(h, 200, bri);

    leds[xy(stars[i].x, stars[i].y)] |= c;
    if (bri > 180) {
      uint8_t nx = stars[i].x, ny = stars[i].y;
      if (nx > 0)        leds[xy(nx-1, ny)] |= CHSV(h, 200, bri >> 2);
      if (nx < gW - 1)   leds[xy(nx+1, ny)] |= CHSV(h, 200, bri >> 2);
      if (ny > 0)        leds[xy(nx, ny-1)] |= CHSV(h, 200, bri >> 2);
      if (ny < gH - 1)   leds[xy(nx, ny+1)] |= CHSV(h, 200, bri >> 2);
    }
  }
}

// =============================================================================
//  PATTERN 0 — IDLE / WAITING  (no backend connection or signal too weak)
//  Slow breathing pulse in neutral blue; shown until real EEG arrives
// =============================================================================

void patternIdle() {
  uint8_t bri = beatsin8(6, 20, 120);
  fill_solid(leds, numLeds(), CHSV(160, 200, bri));
}

// =============================================================================
//  PATTERN ROUTER
// =============================================================================

void renderFrame() {
  if (!state.hasData || state.signal_q < SIGNAL_THRESHOLD) {
    patternIdle();
  } else {
    const String& e = state.emotion;
    if      (e == "calm"     || e == "relaxed")  patternFluidWaves();
    else if (e == "focused")                     patternGeometric();
    else if (e == "stressed" || e == "excited")  patternRhythmicPulse();
    else                                          patternStars();

    // Scale brightness by signal quality
    uint8_t qBri = (uint8_t)map((long)state.signal_q, SIGNAL_THRESHOLD, 100,
                                 80, MAX_BRIGHTNESS);
    FastLED.setBrightness(qBri);
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
      break;

    case WStype_TEXT: {
      StaticJsonDocument<896> doc;
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

      String emo    = doc["emotion"] | "neutral";
      state.emotion = emo;
      state.hue     = emotionToHue(emo);
      state.hasData = true;

      // ── Grid dimensions (set by operator in frontend settings) ────────────
      uint8_t newW = (uint8_t)(doc["matrix_width"]  | (int)MATRIX_W);
      uint8_t newH = (uint8_t)(doc["matrix_height"] | (int)MATRIX_H);
      applyGridSize(newW, newH);

      Serial.printf("[EEG] %-8s  α=%.2f  β=%.2f  θ=%.2f  Q=%.0f  grid=%ux%u\n",
                    emo.c_str(),
                    state.alpha, state.beta, state.theta, state.signal_q,
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

  // ── WiFi ─────────────────────────────────────────────────────────────────
  Serial.printf("[WiFi] Connecting to %s", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
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
