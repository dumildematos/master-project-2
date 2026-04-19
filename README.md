# Sentio

EEG → Emotion → Generative Fashion

## Applications

| App | Tech | Purpose |
|-----|------|---------|
| `backend/` | Python + FastAPI | Signal processing, AI emotion inference, OSC → TouchDesigner, WebSocket → React |
| `frontend/` | React + Vite | Live EEG charts, emotion display, AI guidance |
| `eeg_simulator/` | Python + LSL | Synthetic EEG stream for development without Muse hardware |

## Quick Start

### 1. Backend

```bash
cd backend
python -m venv .venv
.venv/Scripts/python.exe -m pip install -r requirements.txt
.venv/Scripts/python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000
```

### 2. EEG Simulator (if no Muse headband)

```bash
cd eeg_simulator
pip install -r requirements.txt
python simulator.py --scenario cycle
```

### 3. Frontend

```bash
cd frontend
npm install
npm run dev
# Open http://localhost:3000
```

### 4. TouchDesigner

- Add an **OSC In CHOP** listening on `127.0.0.1:7000`
- Address pattern: `/sentio/*`
- Map channels: `colorHue`, `flowSpeed`, `distortion`, `particleDensity`, `brightness`

## Pipeline

```ini
Muse → BlueMuse → LSL → backend/eeg_reader.py
                           ↓
                    signal_processor.py  (alpha/beta/theta)
                           ↓
                    emotion_engine.py    (calm/focused/stressed…)
                           ↓
                    design_mapper.py     (hue/speed/distortion…)
                           ↓
              ┌────────────┴────────────┐
         OSC (port 7000)         WebSocket (port 8000)
              ↓                         ↓
       TouchDesigner              React frontend
```
