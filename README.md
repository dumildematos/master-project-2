# Sentio

**EEG → Emotion → Wearable Light**

Sentio reads brainwaves from a Muse 2 headband, classifies emotional states in real time, and drives a WS2812B LED grid embedded in a garment — turning neuroscience into wearable art.

---

## Architecture

```
Muse 2 (Bluetooth)
    ↓
BlueMuse / BrainFlow  ← LSL stream
    ↓
FastAPI Backend  (signal processing · emotion AI · heart rate)
    ↓  WebSocket /ws/brain-stream
React Dashboard  ←→  Arduino ESP32
                           ↓
                    WS2812B 8×8 LED Grid
```

---

## Applications

| Directory | Tech | Purpose |
|-----------|------|---------|
| `backend/` | Python · FastAPI | EEG signal processing, AI emotion inference, heart-rate, WebSocket broadcast |
| `frontend/` | React · Vite · TypeScript | Live EEG monitoring dashboard, emotion display, manual override |
| `arduino/` | C++ · ESP32 · FastLED | WS2812B LED grid — receives WebSocket data, renders emotion patterns |
| `eeg_simulator/` | Python · LSL | Synthetic EEG stream for development without Muse hardware |

---

## Quick Start

### 1. Backend

```bash
cd backend
python -m venv .venv

# Windows
.venv\Scripts\python.exe -m pip install -r requirements.txt
.venv\Scripts\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000

# macOS / Linux
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

> **Requirements:** Python 3.11+, BrainFlow, heartpy, FastAPI

### 2. EEG Simulator (optional — no Muse hardware needed)

```bash
cd eeg_simulator
pip install -r requirements.txt
python simulator.py --scenario cycle
```

Streams synthetic multi-band EEG over LSL so the backend can process without a real headset.

### 3. Frontend Dashboard

```bash
cd frontend
npm install
npm run dev
# Open http://localhost:3000
```

### 4. Arduino LED Grid

See **[arduino/README.md](arduino/README.md)** for the full setup guide.

**Quick steps:**
1. Edit `arduino/sentio_leds/config.h` — set `WIFI_SSID`, `WIFI_PASSWORD`, `WS_HOST`
2. Install board support: **ESP32 by Espressif** in Arduino IDE
3. Install libraries: **FastLED**, **ArduinoJson**, **ArduinoWebsockets**
4. Upload `arduino/sentio_leds/sentio_leds.ino` to your ESP32
5. The board connects to WiFi, opens a WebSocket to the backend, and starts rendering

---

## Emotion → LED Pattern Mapping

| Emotion | Pattern | Colour Palette |
|---------|---------|----------------|
| Calm | Fluid Waves | Steel blue → powder blue |
| Relaxed | Fluid Waves | Mint → aqua green |
| Focused | Geometric Rings | Electric blue → sky blue |
| Excited | Rhythmic Pulse | Magenta → orange → amber |
| Stressed | Rhythmic Pulse | Deep crimson → dark red |
| *(no signal)* | Idle Breathing | Dim white pulse |

---

## LED Grid Configuration (`config.h`)

| Setting | Default | Description |
|---------|---------|-------------|
| `LED_PIN` | `18` | ESP32 GPIO data pin |
| `MATRIX_W` / `MATRIX_H` | `8` / `8` | Grid dimensions |
| `MATRIX_SERPENTINE` | `true` | Serpentine wiring layout |
| `MATRIX_FLIP_Y` | `false` | Flip Y axis if mounted upside-down |
| `MAX_BRIGHTNESS` | `80` | 0–255 (keep ≤ 100 on USB power) |
| `COLOR_ORDER` | `GRB` | Most WS2812B strips use GRB |
| `TARGET_FPS` | `30` | Animation frame rate |
| `SIGNAL_THRESHOLD` | `20` | Min signal quality before idle pattern |
| `WS_HOST` | `"192.168.1.100"` | Backend IP / hostname |
| `WS_PORT` | `8000` | Backend port |

---

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/session/start` | Start EEG session, connect Muse |
| `POST` | `/session/stop` | Stop active session |
| `GET` | `/session/status` | Current session state |
| `PATCH` | `/session/sensitivity` | Update signal sensitivity live |
| `PATCH` | `/session/emotion-smoothing` | Update emotion smoothing live |
| `GET` | `/calibration/run` | Run baseline calibration |
| `POST` | `/manual/override` | Inject manual EEG values (demo mode) |
| `GET` | `/pattern/generate` | Generate pattern params for an emotion |
| `WS` | `/ws/brain-stream` | Real-time EEG · emotion · pattern stream |

---

## WebSocket Message Format

```jsonc
{
  "timestamp": 1713600000.0,
  "alpha": 0.42, "beta": 0.21, "theta": 0.18, "gamma": 0.11, "delta": 0.08,
  "signal_quality": 84.5,
  "heart_bpm": 68.3,
  "heart_confidence": 0.91,
  "respiration_rpm": 14.2,
  "emotion": "calm",
  "confidence": 0.87,
  "detected_emotion": "calm",
  "pattern_seed": 42,
  "pattern_type": "fluid",
  "pattern_complexity": 0.6,
  "color_palette": ["#4F6D7A", "#A6C8D8", "#E6F1F5", "#2E4057"],
  "active": 1
}
```

---

## Deployment (Vercel)

The project can be deployed to Vercel as two linked services:

```json
{
  "experimentalServices": {
    "frontend": { "entrypoint": "frontend", "routePrefix": "/",         "framework": "vite" },
    "backend":  { "entrypoint": "backend",  "routePrefix": "/_/backend" }
  }
}
```

Set `VITE_API_BASE_URL=/_/backend` in `frontend/.env.production`.

---

## Hardware Requirements

| Component | Details |
|-----------|---------|
| Muse 2 headband | EEG source — 4 channels, 256 Hz |
| ESP32 dev board | WiFi + WebSocket client |
| WS2812B LED strip / matrix | 8×8 = 64 LEDs (scalable) |
| 5 V / 3 A power supply | For 64 LEDs at full brightness |
| 300–500 Ω resistor | Data line protection |
| 1000 µF capacitor | Power rail decoupling |

---

## Project Structure

```
master-project-2/
├── arduino/
│   ├── sentio_leds/
│   │   ├── sentio_leds.ino   # Main sketch
│   │   └── config.h          # All hardware & network settings
│   └── README.md             # Full Arduino setup guide
├── backend/
│   ├── api/                  # FastAPI routes + WebSocket
│   ├── eeg/                  # Muse connection, signal processing
│   ├── emotion/              # Emotion classification model
│   ├── patterns/             # Pattern parameter mapper
│   ├── services/             # Session manager, stream service
│   ├── heart_rate.py         # HeartPy-based BPM + respiration
│   └── main.py
├── frontend/
│   └── src/
│       ├── context/          # BrainContext WebSocket provider
│       ├── components/       # Dashboard screens & panels
│       ├── hooks/            # useManualMode, useWebSocket
│       └── lib/              # runtimeConfig, emotionMeta
├── eeg_simulator/            # Synthetic LSL EEG stream
├── docs/                     # GitHub Pages landing page
└── vercel.json
```

---

## License

MIT — see [LICENSE](LICENSE) for details.
