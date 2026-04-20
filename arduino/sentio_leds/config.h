// =============================================================================
//  config.h  —  Sentio LED T-shirt  (edit this file for your setup)
// =============================================================================
#pragma once

// ── LED matrix ───────────────────────────────────────────────────────────────
#define LED_PIN         5          // ESP32 GPIO connected to WS2812B DIN

// MATRIX_W / MATRIX_H set the PHYSICAL maximum of your LED panel.
// Set these to the actual number of columns and rows you have soldered.
// They are used only to allocate the leds[] array at compile time — the
// runtime grid is controlled from the frontend (8×8 / 16×16 / 32×32 /
// 64×64 / Fit) and arrives via WebSocket; the sketch applies it immediately
// without a reflash.  Values larger than MATRIX_W / MATRIX_H are clamped.
//
// Example physical panels:
//   8×8   →  MATRIX_W 8,  MATRIX_H 8   (64 LEDs)
//   16×16 →  MATRIX_W 16, MATRIX_H 16  (256 LEDs)  ← default
//   10×20 →  MATRIX_W 20, MATRIX_H 10  (200 LEDs, Assembly Manual panel)
//   32×32 →  MATRIX_W 32, MATRIX_H 32  (1024 LEDs — needs 5 V / 20 A supply)
#define MATRIX_W        16         // physical columns  (compile-time allocation)
#define MATRIX_H        16         // physical rows     (compile-time allocation)
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
