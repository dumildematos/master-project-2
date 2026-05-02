#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <FastLED.h>
#include "esp_wpa2.h"  // for enterprise WiFi

// ======================================================
// 🔧 CONFIG
// ======================================================

// ---- Choose WiFi mode ----
#define USE_ENTERPRISE_WIFI false

// ---- Normal WiFi ----
const char* ssid     = "YOUR_WIFI";
const char* password = "YOUR_PASSWORD";

// ---- Enterprise WiFi (if needed) ----
const char* eap_identity = "username";
const char* eap_username = "username";
const char* eap_password = "password";

// ---- Backend API ----
const char* apiUrl = "http://192.168.1.100:8000/device/emotion";

// ---- LED ----
#define LED_PIN 5
#define NUM_LEDS 64
#define BRIGHTNESS 80

CRGB leds[NUM_LEDS];

// ---- State ----
String currentEmotion = "calm";
unsigned long lastFetch = 0;

// ======================================================
// 🔌 SETUP
// ======================================================
void setup() {
  Serial.begin(115200);

  FastLED.addLeds<WS2812, LED_PIN, GRB>(leds, NUM_LEDS);
  FastLED.setBrightness(BRIGHTNESS);

  connectWiFi();
}

// ======================================================
// 🔁 LOOP
// ======================================================
void loop() {
  if (WiFi.status() == WL_CONNECTED) {
    fetchEmotion();
  }

  renderEmotion();
  delay(30);
}

// ======================================================
// 🌐 WIFI CONNECTION
// ======================================================
void connectWiFi() {
  Serial.println("Connecting to WiFi...");

#if USE_ENTERPRISE_WIFI

  WiFi.disconnect(true);
  WiFi.mode(WIFI_STA);

  esp_wifi_sta_wpa2_ent_set_identity((uint8_t *)eap_identity, strlen(eap_identity));
  esp_wifi_sta_wpa2_ent_set_username((uint8_t *)eap_username, strlen(eap_username));
  esp_wifi_sta_wpa2_ent_set_password((uint8_t *)eap_password, strlen(eap_password));

  esp_wifi_sta_wpa2_ent_enable();

  WiFi.begin(ssid);

#else

  WiFi.begin(ssid, password);

#endif

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\nConnected!");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());
}

// ======================================================
// 📡 FETCH EMOTION FROM API
// ======================================================
void fetchEmotion() {
  if (millis() - lastFetch < 2000) return; // every 2 sec
  lastFetch = millis();

  HTTPClient http;
  http.begin(apiUrl);

  int code = http.GET();

  if (code == 200) {
    String payload = http.getString();

    DynamicJsonDocument doc(256);
    deserializeJson(doc, payload);

    currentEmotion = doc["emotion"].as<String>();
    Serial.println("Emotion: " + currentEmotion);
  } else {
    Serial.println("API error");
  }

  http.end();
}

// ======================================================
// 🎨 RENDER EMOTION
// ======================================================
void renderEmotion() {
  if (currentEmotion == "calm") calmEffect();
  else if (currentEmotion == "focused") focusedEffect();
  else if (currentEmotion == "stressed") stressedEffect();
  else if (currentEmotion == "relaxed") relaxedEffect();
  else if (currentEmotion == "excited") excitedEffect();
}

// ======================================================
// 🎨 LED EFFECTS
// ======================================================

// 🌊 CALM → Blue smooth waves
void calmEffect() {
  static uint8_t t = 0;
  t++;

  for (int i = 0; i < NUM_LEDS; i++) {
    uint8_t wave = sin8(i * 8 + t);
    leds[i] = CHSV(160, 200, wave);
  }

  FastLED.show();
}

// 🎯 FOCUSED → Green center pulse
void focusedEffect() {
  fill_solid(leds, NUM_LEDS, CRGB::Black);

  int center = 27;

  leds[center] = CRGB::Green;
  leds[center + 1] = CRGB::Green;
  leds[center + 8] = CRGB::Green;
  leds[center + 9] = CRGB::Green;

  for (int i = 0; i < NUM_LEDS; i++) {
    if (random8() < 15) {
      leds[i] = CRGB(0, 100, 0);
    }
  }

  FastLED.show();
}

// 🔥 STRESSED → Red chaotic flicker
void stressedEffect() {
  for (int i = 0; i < NUM_LEDS; i++) {
    leds[i] = CRGB(random8(255), 0, 0);
  }

  FastLED.show();
  delay(40);
}

// 🌸 RELAXED → Purple flowing
void relaxedEffect() {
  static uint8_t t = 0;
  t++;

  for (int i = 0; i < NUM_LEDS; i++) {
    uint8_t val = sin8(i * 6 + t);
    leds[i] = CHSV(200, 150, val);
  }

  FastLED.show();
}

// ⚡ EXCITED → Yellow burst
void excitedEffect() {
  fill_solid(leds, NUM_LEDS, CRGB::Black);

  int center = 27;
  leds[center] = CRGB::Orange;

  for (int i = 0; i < NUM_LEDS; i++) {
    if (random8() > 220) {
      leds[i] = CRGB::Yellow;
    }
  }

  FastLED.show();
}