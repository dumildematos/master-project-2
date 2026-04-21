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

| Emotion | Pattern | Colour Palette | Visual Feel |
|---------|---------|----------------|------------|
| Calm | Fluid Waves | Steel blue → powder blue | Slow, flowing sine ripples |
| Relaxed | Fluid Waves | Mint → aqua green | Gentle, organic movement |
| Focused | Geometric Rings | Electric blue → sky | Sharp concentric rings |
| Excited | Rhythmic Pulse | Magenta → orange → amber | Fast, energetic bursts |
| Stressed | Rhythmic Pulse | Deep crimson → dark red | Urgent pulsing |
| *(no signal)* | Idle Breathing | Dim white pulse | Slow heartbeat waiting |

Brightness auto-scales from the live `signal_quality` and `confidence` values —
the shirt glows brighter when the EEG signal is cleaner.

---

## LED Strip Configuration (`config.h`)

The strip runs in **serpentine rows** across the shirt body.  At 60 LEDs/m the
spacing between LEDs is 1.67 cm, so a 42 cm wide shirt fits ~25 LEDs/row and
12 rows = 300 LEDs — the full 5 m roll.

| Setting | Default | Description |
|---------|---------|-------------|
| `LED_PIN` | `18` | ESP32 GPIO data pin (via 330 Ω resistor) |
| `MATRIX_W` | `25` | LEDs per row — set to match your shirt width |
| `MATRIX_H` | `12` | Number of rows — set to match shirt height |
| `MATRIX_SERPENTINE` | `true` | Odd rows run right-to-left (standard strip layout) |
| `MATRIX_FLIP_Y` | `false` | Flip Y if row 0 is at the shirt hem, not collar |
| `MAX_BRIGHTNESS` | `60` | 24 % — vivid through fabric, safe on USB bank |
| `COLOR_ORDER` | `GRB` | BTF-LIGHTING WS2812B uses GRB |
| `TARGET_FPS` | `30` | Animation frame rate |
| `SIGNAL_THRESHOLD` | `20` | Min signal quality before switching to idle pattern |
| `WS_HOST` | `"192.168.1.100"` | Backend IP — run `ipconfig` / `ifconfig` to find it |
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

## Hardware

| Component | Model / Spec | Notes |
|-----------|-------------|-------|
| EEG headband | Muse 2 | 4-channel EEG, 256 Hz via Bluetooth |
| Microcontroller | ESP32 Dev Module | WiFi + WebSocket client |
| LED strip | **BTF-LIGHTING WS2812B 5 m · 60 LEDs/m · DC 5 V** | 300 addressable RGB LEDs sewn inside the t-shirt |
| Power — portable | USB power bank ≥ 10 000 mAh (5 V / 3 A output) | Set `MAX_BRIGHTNESS 40`; powers ~2–3 h |
| Power — performance | 5 V / 10 A regulated supply | Full brightness for exhibitions |
| Data resistor | 330–470 Ω | In series on the DIN line |
| Decoupling cap | 470–1000 µF electrolytic | Across 5 V / GND at strip start |
| Garment | Black t-shirt, heavy cotton | Dark fabric diffuses LEDs evenly |

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
