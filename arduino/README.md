# Sentio LED Grid — Arduino / ESP32

EEG-driven WS2812B 8×8 LED grid.  
The ESP32 connects to the Sentio Python backend over WiFi via WebSocket
and renders one of four emotion-driven patterns in real time.

---

## Hardware

| Part | Qty | Notes |
|------|-----|-------|
| ESP32 Dev Module | 1 | Any standard ESP32 board |
| WS2812B 8×8 LED matrix | 1 | 64 LEDs — flexible or rigid panel |
| 5 V / 3 A power supply | 1 | 64 LEDs @ full white ≈ 3.8 A peak; USB is OK at ≤ brightness 80 |
| 330–470 Ω resistor | 1 | In series with data line — prevents ringing |
| 100–470 µF capacitor | 1 | Across 5 V / GND near the matrix power pads |

### Wiring

```
ESP32 GPIO 18 ──[330Ω]──→  WS2812B DIN
ESP32 GND     ───────────  WS2812B GND
5 V supply    ───────────  WS2812B 5 V
5 V supply    ───────────  ESP32 VIN  (or power ESP32 separately from USB)
```

> ⚠️ Never draw LED power from the ESP32's 3.3 V or onboard 5 V pin.
> Use a dedicated 5 V rail.  Keep `MAX_BRIGHTNESS ≤ 80` when powered from USB.

---

## Patterns

| Emotion | Pattern | Visual description |
|---------|---------|-------------------|
| `calm` / `relaxed` | **Fluid Waves** | Plasma sine-wave overlay — slow, flowing |
| `focused` | **Geometric Rings** | Rotating concentric circles — sharp, structured |
| `stressed` / `excited` | **Rhythmic Pulse** | Expanding rings + cross arms — fast, urgent |
| `neutral` / `organic` | **Star Field** | Independently twinkling stars with soft halos |
| no signal / idle | **Breathing Blue** | Slow pulsing blue — waiting for EEG data |

---

## Setup

### 1 — Install Arduino IDE 2.x

Download from [arduino.cc/en/software](https://www.arduino.cc/en/software).

### 2 — Add ESP32 board support

`File → Preferences → Additional boards manager URLs`:

```
https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
```

`Tools → Board → Boards Manager` → search **esp32** → install the Espressif package.

### 3 — Install libraries

`Tools → Manage Libraries` → install:

| Library | Author | Version |
|---------|--------|---------|
| **FastLED** | Daniel Garcia | latest |
| **arduinoWebSockets** | Markus Sattler | latest |
| **ArduinoJson** | Benoit Blanchon | **6.x** (not v7) |

### 4 — Configure `config.h`

Open `arduino/sentio_leds/config.h` and fill in your settings:

```cpp
// ── Grid ─────────────────────────────────────────────────────────────────
#define LED_PIN        18        // GPIO pin connected to DIN
#define MATRIX_W       8
#define MATRIX_H       8
#define MAX_BRIGHTNESS 80        // reduce if using USB power

// ── WiFi ─────────────────────────────────────────────────────────────────
#define WIFI_AUTH_MODE 0         // 0 = home WPA2   1 = WPA2-Enterprise
#define WIFI_SSID      "YourNetwork"
#define WIFI_PASSWORD  "YourPassword"

// ── Backend ───────────────────────────────────────────────────────────────
#define WS_HOST  "192.168.1.100" // IP of the machine running the Sentio backend
#define WS_PORT  8000
```

**Finding the backend machine IP:**

| OS | Command |
|----|---------|
| Windows | `ipconfig` → look for IPv4 Address |
| macOS | `ifconfig en0` → `inet` line |
| Linux | `ip a` → `inet` line |

**WPA2-Enterprise (university networks):**  
Set `WIFI_AUTH_MODE 1` and fill in `WIFI_USERNAME` / `WIFI_PASSWORD`.

### 5 — Select board and upload

1. `Tools → Board → ESP32 Arduino → ESP32 Dev Module`
2. `Tools → Port → COMx` (Windows) or `/dev/ttyUSB0` (Linux/macOS)
3. Click **Upload** (Ctrl+U)

### 6 — Start the Sentio backend

```bash
cd backend
uvicorn main:app --host 0.0.0.0 --port 8000
```

The ESP32 connects automatically and starts rendering patterns
as soon as EEG data flows from the Muse headband.

---

## Serial Monitor

Open Serial Monitor at **115200 baud** to watch the live data:

```
╔═══════════════════════════════╗
║  Sentio LED Grid  8×8          ║
╚═══════════════════════════════╝
[WiFi] Connected  IP=192.168.1.42  RSSI=-52 dBm
[WS]   Connected → ws://192.168.1.100:8000/ws/brain-stream
[EEG]  calm       pattern=fluid      α=0.65 β=0.18 θ=0.23 γ=0.06  Q=87  conf=0.84
[EEG]  calm       pattern=fluid      α=0.68 β=0.16 θ=0.25 γ=0.05  Q=89  conf=0.86
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| LEDs show wrong colours | Change `COLOR_ORDER GRB` → `RGB` in `config.h` |
| Pattern is upside down | Toggle `MATRIX_FLIP_Y` in `config.h` |
| Pattern is mirrored | Toggle `MATRIX_SERPENTINE` in `config.h` |
| LED 0 is not top-left | Adjust `MATRIX_FLIP_Y` and `MATRIX_SERPENTINE` to match your wiring |
| Only idle blue, no patterns | Check backend is running; verify `WS_HOST` IP; open Serial Monitor |
| WiFi won't connect | Double-check `WIFI_SSID` / `WIFI_PASSWORD`; for enterprise set `WIFI_AUTH_MODE 1` |
| `fatal error: esp_eap_client.h` | Update ESP32 board package to latest version |
| Flickering LEDs | Add 330 Ω resistor on data line; add 470 µF cap on power rails |
| Low brightness / dim | Increase `MAX_BRIGHTNESS` (max 255, reduce if on USB) |
