// =============================================================================
//  config.h  —  Sentio LED T-shirt  (edit this file for your setup)
// =============================================================================
#pragma once

// ── LED matrix ───────────────────────────────────────────────────────────────
#define LED_PIN         5          // ESP32 GPIO connected to WS2812B DIN

// MATRIX_W / MATRIX_H define the MAXIMUM physical size of the panel.
// They are used only to allocate the leds[] array at compile time.
//
// At runtime the backend streams matrix_width and matrix_height in every
// WebSocket frame (set by the operator in the frontend settings panel).
// The sketch applies those values immediately — no reflash needed.
// Values received from the backend are clamped to [1, MATRIX_W] / [1, MATRIX_H].
#define MATRIX_W        16         // maximum columns  (compile-time allocation)
#define MATRIX_H        16         // maximum rows     (compile-time allocation)
#define NUM_LEDS        (MATRIX_W * MATRIX_H)  // compile-time max LED count

// Wiring direction: set true if LED 0 is at BOTTOM-left of the matrix
// (flip so patterns appear upright when worn)
#define MATRIX_FLIP_Y   true

// Serpentine wiring: set true if odd rows run right-to-left (most matrices)
#define MATRIX_SERPENTINE true

// Max brightness (0-255). Keep ≤ 180 when running on battery.
#define MAX_BRIGHTNESS  160

// Colour order of your strip (WS2812B = GRB, but some clones differ)
#define COLOR_ORDER     GRB
#define LED_TYPE        WS2812B

// ── WiFi ─────────────────────────────────────────────────────────────────────
#define WIFI_SSID       "YOUR_WIFI_SSID"
#define WIFI_PASSWORD   "YOUR_WIFI_PASSWORD"

// ── Backend WebSocket ─────────────────────────────────────────────────────────
// IP address of the machine running the Python backend
#define WS_HOST         "192.168.1.100"
#define WS_PORT         8000
#define WS_PATH         "/ws/brain-stream"

// Reconnect attempt interval (ms) when WebSocket is lost
#define WS_RECONNECT_MS 3000

// ── Animation ────────────────────────────────────────────────────────────────
// Frames per second target
#define TARGET_FPS      30

// Below this signal_quality (0-100) the idle "waiting" pattern is shown
#define SIGNAL_THRESHOLD 20
