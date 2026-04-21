// =============================================================================
//  config.h  —  Sentio LED T-Shirt  (edit this file for your setup)
//
//  Hardware: BTF-LIGHTING WS2812B 5 m · 60 LEDs/m · DC 5 V · non-waterproof
//  Strip is sewn in serpentine rows inside the garment lining.
//  Full strip = 300 LEDs  →  MATRIX_W × MATRIX_H must equal 300.
// =============================================================================
#pragma once

// ── LED strip / matrix layout ─────────────────────────────────────────────────
//
//  BTF-LIGHTING 5 m × 60 LEDs/m = 300 LEDs total.
//  The strip runs in horizontal rows (serpentine) across the shirt body.
//
//  Typical t-shirt body (adult M):
//    width  ~45 cm  →  45 / 1.67 cm ≈ 27 LEDs/row  (1.67 cm between LEDs at 60/m)
//    height ~50 cm  →  300 / 25    = 12 rows
//
//  Adjust MATRIX_W and MATRIX_H to fit YOUR shirt.
//  Rule: MATRIX_W × MATRIX_H must equal 300 (or how many LEDs you actually use).
//
#define LED_PIN         18            // ESP32 GPIO pin → 330 Ω resistor → DIN

#define MATRIX_W        25            // LEDs per horizontal row across the shirt
#define MATRIX_H        12            // number of sewn rows (height of the panel)
#define NUM_LEDS        (MATRIX_W * MATRIX_H)   // 300 = full 5 m BTF-LIGHTING strip

// Wiring layout — serpentine means odd rows run right-to-left.
// Flip Y if row 0 is at the bottom of the shirt instead of the top.
#define MATRIX_SERPENTINE  true
#define MATRIX_FLIP_Y      false

// Colour order. BTF-LIGHTING WS2812B = GRB. If colours look wrong, try RGB.
#define COLOR_ORDER     GRB
#define LED_TYPE        WS2812B

// ── Brightness ───────────────────────────────────────────────────────────────
//
//  300 LEDs full-white @ 60 mA = 18 A peak.  Use a 5 V / 10 A supply for
//  performances.  On a USB power bank limit to brightness ≤ 40 (~1.5 A draw).
//  Fabric diffusion naturally softens the output — lower values look better.
//
#define MAX_BRIGHTNESS  60            // 0–255 · 60 ≈ 20 % · safe on 3 A USB bank

// ── WiFi ─────────────────────────────────────────────────────────────────────
// Auth mode:
//   0 = WPA/WPA2 Personal  (home / hotspot)
//   1 = WPA2-Enterprise / 802.1X  (university network)
#define WIFI_AUTH_MODE  0             // ← change to 1 for WPA2-Enterprise

#define WIFI_SSID       "YourNetwork"
#define WIFI_PASSWORD   "YourPassword"

// WPA2-Enterprise only (WIFI_AUTH_MODE 1)
#define WIFI_USERNAME   "student_id"
#define WIFI_IDENTITY   WIFI_USERNAME

// ── Sentio backend ────────────────────────────────────────────────────────────
// IP address of the computer running the Python backend.
// Find it with: Windows → ipconfig | macOS/Linux → ifconfig / ip a
//
// TIP: If you use a phone hotspot, set the backend host here and connect
//      both the ESP32 and the laptop to the same hotspot.
#define WS_HOST         "192.168.1.100"
#define WS_PORT         8000
#define WS_PATH         "/ws/brain-stream"
#define WS_RECONNECT_MS 3000          // ms between reconnect attempts

// ── Animation ────────────────────────────────────────────────────────────────
#define TARGET_FPS      30            // frames per second rendered on the strip

// signal_quality below this → idle breathing pattern (no EEG data yet)
#define SIGNAL_THRESHOLD  20          // 0–100
