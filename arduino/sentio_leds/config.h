// =============================================================================
//  config.h  —  Sentio 8×8 LED Grid  (edit this file for your setup)
// =============================================================================
#pragma once

// ── LED matrix ───────────────────────────────────────────────────────────────
#define LED_PIN         18            // ESP32 GPIO pin connected to DIN of WS2812B
#define MATRIX_W        8             // columns  (8 for an 8×8 grid)
#define MATRIX_H        8             // rows     (8 for an 8×8 grid)
#define NUM_LEDS        (MATRIX_W * MATRIX_H)   // 64 LEDs

// Wiring layout flags — match these to how your matrix is physically wired.
// MATRIX_SERPENTINE  true  → odd rows run right-to-left (most pre-built panels)
// MATRIX_FLIP_Y      true  → row 0 is at the BOTTOM (flip for upright display)
#define MATRIX_SERPENTINE  true
#define MATRIX_FLIP_Y      false

// Colour order. WS2812B = GRB. Some clones are RGB — change if colours look wrong.
#define COLOR_ORDER     GRB
#define LED_TYPE        WS2812B

// Max brightness 0–255.
// Keep ≤ 100 on USB power.  Full white 64 LEDs @ 255 draws ~3.8 A.
#define MAX_BRIGHTNESS  80

// ── WiFi ─────────────────────────────────────────────────────────────────────
// Auth mode:
//   0 = WPA/WPA2 Personal  (home/standard — just SSID + password)
//   1 = WPA2-Enterprise / 802.1X  (university networks — needs SSID + user + pass)
#define WIFI_AUTH_MODE  0             // ← change to 1 for WPA2-Enterprise

#define WIFI_SSID       "YourNetwork"
#define WIFI_PASSWORD   "YourPassword"

// WPA2-Enterprise only (WIFI_AUTH_MODE 1)
#define WIFI_USERNAME   "student_id"
#define WIFI_IDENTITY   WIFI_USERNAME  // usually the same as username

// ── Sentio backend ────────────────────────────────────────────────────────────
// IP address of the computer running the Python backend.
// Find it with: Windows → ipconfig | macOS/Linux → ifconfig
#define WS_HOST         "192.168.1.100"
#define WS_PORT         8000
#define WS_PATH         "/ws/brain-stream"
#define WS_RECONNECT_MS 3000          // ms between reconnect attempts

// ── Animation ────────────────────────────────────────────────────────────────
#define TARGET_FPS      30            // target frames per second

// signal_quality below this value → idle "waiting" pattern instead of EEG pattern
#define SIGNAL_THRESHOLD  20          // 0–100
