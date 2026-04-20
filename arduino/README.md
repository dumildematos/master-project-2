# Sentio LED T-shirt — Arduino / ESP32

EEG-driven WS2812B LED matrix worn on a t-shirt chest.  
The ESP32 connects to the Sentio Python backend over WiFi and renders
one of four patterns based on the detected emotion.

---

## Hardware

| Part | Qty | Notes |
|------|-----|-------|
| ESP32-S2 board | 1 | Select the matching S2 board profile in Arduino IDE |
| WS2812B flexible LED matrix | 1 | 16 × 16 = 256 LEDs recommended |
| 5 V power supply / LiPo + boost | 1 | 256 LEDs @ full white ≈ 15 A peak; keep brightness ≤ 160 for battery |
| 330–500 Ω resistor | 1 | In series with data line (reduces ringing) |
| 100–1000 µF capacitor | 1 | Across 5 V / GND near the matrix |

### Wiring

```ini
ESP32 GPIO 5  ──[330Ω]──→  WS2812B DIN
ESP32 GND     ────────────  WS2812B GND
5 V supply    ────────────  WS2812B 5V
5 V supply    ────────────  ESP32 VIN  (or power ESP32 separately via USB)
```

> **Do not power the LED matrix from the ESP32 3.3 V or 5 V pin.**  
> Use a dedicated 5 V rail capable of at least 3 A for a 16×16 matrix.

---

## Patterns (emotion-driven)

| Emotion | Pattern | Portuguese name |
|---------|---------|-----------------|
| calm / relaxed | Plasma sine waves | Ondas Fluidas |
| focused | Rotating concentric rings | Padrão Geométrico |
| stressed / excited | Cross arms + pulse rings | Pulsos Rítmicos |
| neutral | Twinkling star field | Estrelas e Partículas |
| no signal | Slow breathing blue | Idle |

---

## Setup

### 1. Install Arduino IDE 2.x

### 2. Add ESP32 board support

`File → Preferences → Additional Boards Manager URLs`:

```ini
https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
```

Then `Tools → Board → Boards Manager` → search **esp32** → install.

### 3. Install libraries

`Tools → Manage Libraries`:

- **FastLED** by Daniel Garcia
- **arduinoWebSockets** by Markus Sattler
- **ArduinoJson** by Benoit Blanchon (install v6.x)

### 4. Configure `config.h`

```cpp
#define WIFI_SSID     "your-network"
#define WIFI_PASSWORD "your-password"
#define WS_HOST       "192.168.X.X"   // IP of the machine running the backend
```

Find the backend machine IP:

- **Windows**: `ipconfig` → IPv4 Address
- **macOS/Linux**: `ifconfig` or `ip a`

### 5. Select board and port

`Tools → Board → ESP32 Arduino → ESP32S2 Dev Module` for ESP32-S2 boards  
Use `ESP32 Dev Module` only if the chip is a classic ESP32, not S2.  
`Tools → Port → COMx` (Windows) or `/dev/ttyUSB0` (Linux)

### 6. Upload

Click **Upload** (→ arrow).

---

## Matrix size / wiring direction

Edit `config.h` if your matrix is a different size:

```cpp
#define MATRIX_W        16    // columns
#define MATRIX_H        16    // rows
#define MATRIX_FLIP_Y   true  // flip if patterns appear upside-down
#define MATRIX_SERPENTINE true // false if all rows run the same direction
```

---

## Backend requirements

The backend must be running and streaming before the ESP32 will show patterns.
The ESP32 connects as a standard WebSocket client to:

```sh
ws://<WS_HOST>:8000/ws/brain-stream
```

No backend changes are needed — it is the same stream used by the frontend.

The firmware consumes these WebSocket fields directly: `pattern_type`, `pattern_complexity`, `color_palette`, `matrix_width`, `matrix_height`, `signal_quality`, `confidence`, and the EEG bands.
If a field is missing, the sketch falls back to emotion-based defaults so it still renders safely.

Start backend:

```bash
cd backend
uvicorn main:app --host 0.0.0.0 --port 8000
```

> `--host 0.0.0.0` is required so the ESP32 can reach it over WiFi.

---

## Serial monitor

Open `Tools → Serial Monitor` at **115200 baud** to see connection status and
live EEG readings:

```ini
[WiFi] Connecting to MyNetwork...
[WiFi] Connected  IP=192.168.1.42
[WS]  Connecting to ws://192.168.1.100:8000/ws/brain-stream
[WS]  Connected to Sentio backend
[EEG] calm      α=0.68  β=0.18  θ=0.16  Q=87
```
