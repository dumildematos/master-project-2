#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <FastLED.h>
#include "esp_wpa2.h"

// ======================================================
// CONFIG
// ======================================================

const char* ssid     = "";
const char* password = "";

const char* emotionApiUrl = "http://192.168.1.180:8000/api/device/emotion";
const char* patternApiUrl = "http://192.168.1.180:8000/api/device/pattern";

#define LED_PIN   5
#define NUM_LEDS  64
#define ROWS      8
#define COLS      8
#define PREVIEW_TIMEOUT_MS 30000

CRGB leds[NUM_LEDS];

// ── Emotion fallback ────────────────────────────────────
String currentEmotion    = "calm";
unsigned long lastEmotionFetch = 0;

// ── Preview state ───────────────────────────────────────
bool   previewActive     = false;
int    previewGrid[ROWS][COLS];
CRGB   previewPixels[NUM_LEDS]; // per-pixel colors from rgb_grid
bool   hasRgbGrid        = false;
String previewMode       = "static";
CRGB   previewPrimary    = CRGB(0x1A, 0x6E, 0xFF);
CRGB   previewSecondary  = CRGB(0x00, 0xD9, 0xFF);
int    previewBrightness = 80;
int    previewSpeed      = 50;
unsigned long lastPatternFetch = 0;
unsigned long previewSetAt     = 0;
static uint8_t animT = 0;

// ======================================================
// HELPERS
// ======================================================

inline int ledIndex(int r, int c) { return r * COLS + c; }

CRGB hexToRGB(const char* hex) {
  if (!hex || strlen(hex) < 7) return CRGB::Black;
  long val = strtol(hex + 1, nullptr, 16);
  return CRGB((val >> 16) & 0xFF, (val >> 8) & 0xFF, val & 0xFF);
}

// Per-pixel color from rgb_grid; falls back to primary if black/missing
CRGB pixelColor(int r, int c) {
  if (!hasRgbGrid) return previewPrimary;
  CRGB col = previewPixels[ledIndex(r, c)];
  if (col.r == 0 && col.g == 0 && col.b == 0) return previewPrimary;
  return col;
}

CRGB blendColors(uint8_t t) {
  return blend(previewPrimary, previewSecondary, t);
}

// ======================================================
// SETUP
// ======================================================
void setup() {
  Serial.begin(115200);
  delay(500);
  FastLED.addLeds<WS2812, LED_PIN, GRB>(leds, NUM_LEDS);
  FastLED.setBrightness(80);
  memset(previewGrid, 0, sizeof(previewGrid));
  memset(previewPixels, 0, sizeof(previewPixels));

  // Startup flash — confirms wiring works
  fill_solid(leds, NUM_LEDS, CRGB(15, 15, 15));
  FastLED.show(); delay(300);
  fill_solid(leds, NUM_LEDS, CRGB::Black);
  FastLED.show();

  connectWiFi();
}

// ======================================================
// LOOP
// ======================================================
void loop() {
  if (WiFi.status() == WL_CONNECTED) {
    fetchPattern();
    fetchEmotion();
  }

  if (previewActive && millis() - previewSetAt > PREVIEW_TIMEOUT_MS) {
    previewActive = false;
    hasRgbGrid    = false;
    FastLED.setBrightness(80);
    Serial.println("[preview] expired");
  }

  if (previewActive) {
    animT += max(1, previewSpeed / 20);
    FastLED.setBrightness(map(previewBrightness, 0, 100, 0, 255));
    renderPattern();
  } else {
    renderEmotion();
  }

  FastLED.show();
  delay(20);
}

// ======================================================
// WIFI
// ======================================================
void connectWiFi() {
  Serial.println("[wifi] connecting...");
  WiFi.begin(ssid, password);
  int tries = 0;
  while (WiFi.status() != WL_CONNECTED && tries < 40) {
    delay(500); Serial.print("."); tries++;
  }
  if (WiFi.status() == WL_CONNECTED)
    Serial.println("\n[wifi] " + WiFi.localIP().toString());
  else
    Serial.println("\n[wifi] FAILED");
}

// ======================================================
// FETCH PREVIEW PATTERN
// ======================================================
void fetchPattern() {
  if (millis() - lastPatternFetch < 500) return;
  lastPatternFetch = millis();

  HTTPClient http;
  http.begin(patternApiUrl);
  http.setTimeout(3000);
  int code = http.GET();
  if (code != 200) { http.end(); return; }

  String body = http.getString();
  http.end();

  DynamicJsonDocument doc(3072);
  if (deserializeJson(doc, body)) return;
  if (!doc["available"].as<bool>()) return;

  previewMode       = doc["mode"] | "static";
  previewBrightness = doc["brightness"] | 80;
  previewSpeed      = doc["speed"]      | 50;
  previewPrimary    = hexToRGB(doc["colors"][0] | "#1A6EFF");
  previewSecondary  = hexToRGB(doc["colors"][1] | "#00D9FF");

  // Parse binary pattern grid
  JsonArray rows = doc["pattern"].as<JsonArray>();
  int r = 0;
  for (JsonArray row : rows) {
    int c = 0;
    for (int v : row) {
      if (r < ROWS && c < COLS) previewGrid[r][c] = v;
      c++;
    }
    if (++r >= ROWS) break;
  }

  // Parse rgb_grid (per-pixel exact colors from Flutter)
  JsonArray rgbRows = doc["rgb_grid"].as<JsonArray>();
  if (!rgbRows.isNull()) {
    hasRgbGrid = true;
    int rr = 0;
    for (JsonArray rgbRow : rgbRows) {
      int cc = 0;
      for (const char* hex : rgbRow) {
        if (rr < ROWS && cc < COLS)
          previewPixels[ledIndex(rr, cc)] = hexToRGB(hex);
        cc++;
      }
      if (++rr >= ROWS) break;
    }
  } else {
    hasRgbGrid = false;
  }

  if (!previewActive) animT = 0;
  previewActive = true;
  previewSetAt  = millis();
  Serial.printf("[pattern] %s bri=%d spd=%d rgb=%d\n",
    previewMode.c_str(), previewBrightness, previewSpeed, hasRgbGrid);
}

// ======================================================
// FETCH EMOTION
// ======================================================
void fetchEmotion() {
  if (millis() - lastEmotionFetch < 3000) return;
  lastEmotionFetch = millis();
  HTTPClient http;
  http.begin(emotionApiUrl);
  http.setTimeout(3000);
  if (http.GET() == 200) {
    StaticJsonDocument<256> doc;
    if (!deserializeJson(doc, http.getString()))
      currentEmotion = doc["emotion"] | "calm";
  }
  http.end();
}

// ======================================================
// RENDER PREVIEW — animations match Flutter's LedMatrixPreview
// ======================================================
void renderPattern() {
  String m = previewMode;
  m.toLowerCase();
  if      (m == "breathing")            renderBreathing();
  else if (m == "pulse")                renderPulse();
  else if (m == "wave")                 renderWave();
  else if (m == "spectrum")             renderSpectrum();
  else if (m == "fireworks")            renderFireworks();
  else if (m == "spiral")               renderSpiral();
  else if (m == "burst")                renderBurst();
  else if (m == "flicker")              renderFlicker();
  else                                  renderStatic();
}

// Static: exact per-pixel colors from rgb_grid
void renderStatic() {
  for (int r = 0; r < ROWS; r++)
    for (int c = 0; c < COLS; c++)
      leds[ledIndex(r,c)] = previewGrid[r][c] ? pixelColor(r, c) : CRGB::Black;
}

// Breathing: per-pixel rgb_grid colors fading in/out with sine
// Matches Flutter: Color.lerp(primary, secondary, sin) per pixel
void renderBreathing() {
  uint8_t env = sin8(animT);
  for (int r = 0; r < ROWS; r++) {
    for (int c = 0; c < COLS; c++) {
      if (!previewGrid[r][c]) { leds[ledIndex(r,c)] = CRGB::Black; continue; }
      CRGB col = pixelColor(r, c);
      col.nscale8(max((uint8_t)51, env)); // min 20% brightness like Flutter
      leds[ledIndex(r,c)] = col;
    }
  }
}

// Pulse: 3 concentric expanding rings — matches Flutter exactly
// Flutter: 3 rings at phases 0, 1/3, 2/3 expanding to r=4.5, colors primary→secondary
void renderPulse() {
  fill_solid(leds, NUM_LEDS, CRGB::Black);
  float t = animT / 255.0f;
  for (int r = 0; r < ROWS; r++) {
    for (int c = 0; c < COLS; c++) {
      float dx = c - 3.5f, dy = r - 3.5f;
      float d = sqrtf(dx*dx + dy*dy);
      for (int i = 0; i < 3; i++) {
        float rp = fmodf(t + i / 3.0f, 1.0f) * 4.5f;
        if (fabsf(d - rp) < 0.65f) {
          leds[ledIndex(r,c)] = blendColors((uint8_t)(i * 127));
          break;
        }
      }
    }
  }
}

// Wave: sweeping wave front — matches Flutter's wave algorithm
// Flutter: sin(c/7*2PI + t*2PI)*2.5+3.5, 0.9 px wide, primary color
void renderWave() {
  float t = animT / 255.0f;
  for (int r = 0; r < ROWS; r++) {
    for (int c = 0; c < COLS; c++) {
      float waveY = sinf(c / 7.0f * TWO_PI + t * TWO_PI) * 2.5f + 3.5f;
      float dist  = fabsf(r - waveY);
      if (dist < 0.9f) {
        uint8_t bri = (uint8_t)((1.0f - dist / 0.9f) * 255);
        CRGB col = previewPrimary;
        col.nscale8(bri);
        leds[ledIndex(r,c)] = col;
      } else {
        leds[ledIndex(r,c)] = CRGB::Black;
      }
    }
  }
}

// Spectrum: rainbow cycling — matches Flutter's HSV rainbow
// Flutter: HSVColor(hue=(i/64*300 + t*360)%360, s=1, v=0.95)
void renderSpectrum() {
  float t = animT / 255.0f;
  for (int i = 0; i < NUM_LEDS; i++) {
    float hue_deg = fmodf(i / 64.0f * 300.0f + t * 360.0f, 360.0f);
    leds[i] = CHSV((uint8_t)(hue_deg / 360.0f * 255), 255, 242);
  }
}

// Fireworks: exact Flutter dot positions and colors with phase-offset blinking
// Flutter: 16 fixed dots each with unique color and phase offset = (r*8+c)%16
void renderFireworks() {
  fill_solid(leds, NUM_LEDS, CRGB::Black);
  struct Dot { uint8_t r, c; uint8_t red, grn, blu; };
  static const Dot dots[16] = {
    {0,2, 0xFF,0x44,0x00}, {0,5, 0xFF,0xAA,0x00},
    {1,0, 0xFF,0x22,0x00}, {1,7, 0x00,0xDD,0xFF},
    {2,3, 0xFF,0xDD,0x00}, {2,6, 0xFF,0x44,0x00},
    {3,1, 0x00,0xFF,0x88}, {3,5, 0xFF,0x88,0x00},
    {4,3, 0xFF,0x22,0x00}, {4,6, 0xFF,0xAA,0x00},
    {5,0, 0x00,0xDD,0xFF}, {5,4, 0x00,0xFF,0x88},
    {6,2, 0xFF,0x44,0x00}, {6,7, 0xFF,0xDD,0x00},
    {7,1, 0xFF,0x88,0x00}, {7,5, 0x00,0xFF,0x88},
  };
  for (int i = 0; i < 16; i++) {
    uint8_t phase = ((dots[i].r * 8 + dots[i].c) % 16) * 16;
    uint8_t bri = sin8(animT + phase);
    if (bri < 26) continue; // < 10% → off (matches Flutter's a<0.1 threshold)
    CRGB col(dots[i].red, dots[i].grn, dots[i].blu);
    col.nscale8(bri);
    leds[ledIndex(dots[i].r, dots[i].c)] = col;
  }
}

// Spiral: proper angle+distance spiral — matches Flutter's algorithm
// Flutter: angle-based, 0.75 rad arm width, blend primary→secondary by distance
void renderSpiral() {
  float t = animT / 255.0f;
  for (int r = 0; r < ROWS; r++) {
    for (int c = 0; c < COLS; c++) {
      float dx = c - 3.5f, dy = r - 3.5f;
      float d = sqrtf(dx*dx + dy*dy);
      if (d < 0.3f || d > 3.8f) { leds[ledIndex(r,c)] = CRGB::Black; continue; }
      float angle   = fmodf(atan2f(dy, dx) + TWO_PI * 100, TWO_PI);
      float rotated = fmodf(angle - t * TWO_PI + TWO_PI * 100, TWO_PI);
      float armPos  = fmodf(d / 0.55f, TWO_PI);
      float delta   = fabsf(rotated - armPos);
      if (delta > PI) delta = TWO_PI - delta;
      if (delta < 0.75f) {
        leds[ledIndex(r,c)] = blendColors((uint8_t)(d / 3.8f * 255));
      } else {
        leds[ledIndex(r,c)] = CRGB::Black;
      }
    }
  }
}

// Burst: generic radiate-from-center (fallback for unknown modes)
void renderBurst() {
  for (int r = 0; r < ROWS; r++) {
    for (int c = 0; c < COLS; c++) {
      if (!previewGrid[r][c]) { leds[ledIndex(r,c)] = CRGB::Black; continue; }
      float dist = sqrtf(sq(r - 3.5f) + sq(c - 3.5f));
      leds[ledIndex(r,c)] = blendColors(sin8((uint8_t)(dist * 40.0f) - animT));
    }
  }
}

// Flicker: per-pixel rgb_grid colors at random brightness
void renderFlicker() {
  for (int r = 0; r < ROWS; r++) {
    for (int c = 0; c < COLS; c++) {
      if (!previewGrid[r][c]) { leds[ledIndex(r,c)] = CRGB::Black; continue; }
      CRGB col = pixelColor(r, c);
      col.nscale8(random8(80, 255));
      leds[ledIndex(r,c)] = col;
    }
  }
}

// ======================================================
// RENDER EMOTION — autonomous fallback
// ======================================================
void renderEmotion() {
  if      (currentEmotion == "calm")     calmEffect();
  else if (currentEmotion == "focused")  focusedEffect();
  else if (currentEmotion == "stressed") stressedEffect();
  else if (currentEmotion == "relaxed")  relaxedEffect();
  else if (currentEmotion == "excited")  excitedEffect();
}

void calmEffect() {
  static uint8_t t = 0; t++;
  for (int i = 0; i < NUM_LEDS; i++)
    leds[i] = CHSV(160, 200, sin8(i * 8 + t));
}

void focusedEffect() {
  fill_solid(leds, NUM_LEDS, CRGB::Black);
  leds[27] = leds[28] = leds[35] = leds[36] = CRGB::Green;
  for (int i = 0; i < NUM_LEDS; i++)
    if (random8() < 15) leds[i] = CRGB(0, 100, 0);
}

void stressedEffect() {
  for (int i = 0; i < NUM_LEDS; i++)
    leds[i] = CRGB(random8(200), 0, 0);
}

void relaxedEffect() {
  static uint8_t t = 0; t++;
  for (int i = 0; i < NUM_LEDS; i++)
    leds[i] = CHSV(200, 150, sin8(i * 6 + t));
}

void excitedEffect() {
  fill_solid(leds, NUM_LEDS, CRGB::Black);
  leds[27] = CRGB::Orange;
  for (int i = 0; i < NUM_LEDS; i++)
    if (random8() > 220) leds[i] = CRGB::Yellow;
}
