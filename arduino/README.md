# Sentio LED T-Shirt — Arduino / ESP32

EEG-driven wearable light.  
The ESP32 connects to the Sentio backend over WiFi via WebSocket and renders
emotion-driven colour patterns on a **BTF-LIGHTING WS2812B** LED strip sewn
inside a black t-shirt — so the LEDs diffuse through the fabric and glow from within.

---

## Hardware

| Part | Model / Spec | Notes |
|------|-------------|-------|
| LED strip | **BTF-LIGHTING WS2812B 5 m · 60 LEDs/m · DC 5 V · non-waterproof** | 300 individually addressable RGB LEDs |
| Microcontroller | ESP32 Dev Module (38-pin or 30-pin) | Any standard ESP32 board with WiFi |
| Power supply — performance | 5 V / 10 A regulated adapter | Handles 300 LEDs at moderate brightness |
| Power supply — portable | USB power bank ≥ 10 000 mAh with 5 V / 3 A output | Limit `MAX_BRIGHTNESS` to 40 |
| Data resistor | 330–470 Ω | In series on the DIN data line |
| Decoupling capacitor | 470–1000 µF / 10 V electrolytic | Across 5 V + GND at the strip start |
| Garment | Black t-shirt (heavy cotton or jersey) | Dark fabric diffuses LEDs evenly |
| Hookup wire | 22–24 AWG silicone-insulated | Flexible — won't crack with movement |
| Needles + thread | Black polyester thread | For sewing the strip channel |

> **Why non-waterproof?**  The BTF-LIGHTING non-waterproof variant is thinner
> and more flexible, making it far easier to sew flat against fabric.  The
> garment itself keeps the strip away from rain.

---

## Power Budget

| Scenario | Brightness | Current draw | Required supply |
|----------|-----------|--------------|-----------------|
| All white, max | 255 (100 %) | ~18 A peak | 5 V / 20 A (lab use only) |
| Full patterns | 100 (39 %) | ~5.4 A | 5 V / 6 A adapter |
| **Performance (recommended)** | **60 (24 %)** | **~3.2 A** | **5 V / 5 A adapter** |
| USB power bank | 40 (16 %) | ~2.0 A | 10 000 mAh bank (2 A output) |

> Fabric diffusion makes brightness 60 look very vivid — you do **not** need
> full brightness for great visual impact.

---

## Wiring

```
BTF-LIGHTING strip
    DIN  ←──[330Ω]──── ESP32 GPIO 18
    GND  ←──────────── ESP32 GND  ──── 5 V supply GND
    +5V  ←──────────────────────────── 5 V supply (+)
                              │
                         [470µF cap]  (+ toward supply)

ESP32 VIN (or 5V pin) ←──── 5 V supply (+)   ← power ESP32 from same rail
```

### Injection points for long strips

At 60 LEDs/m over 5 m the voltage drop along the strip can dim the far end.
Inject power at **both the start and end** of the strip for even brightness:

```
5 V supply (+) ──────────────────────────────── strip end +5V
5 V supply GND ─────────────────────────────── strip end GND
                               (data line only goes to LED 0)
```

> ⚠️ Only the data line connects to the ESP32.  Power injection wires connect
> **only** to the strip's power pads — never to the ESP32.

---

## Garment Installation Guide

### Materials needed

- Black t-shirt (adult M/L — heavier fabric diffuses better)
- BTF-LIGHTING WS2812B 5 m strip (already cut to size or full roll)
- Sewing needle + black thread, or fabric glue gun
- Small safety pins (for temporary placement)
- Seam ripper (to open the hem for wire routing)
- Electrical tape or heat-shrink for any exposed solder joints

---

### Step 1 — Plan the layout

The strip runs in **serpentine rows** across the shirt body.  Measure the
shirt's inner width (shoulder-to-shoulder seam, usually 40–50 cm).

At 60 LEDs/m spacing = **1 LED every 1.67 cm**:

| Shirt size | Inner width | LEDs/row | Rows | Total |
|-----------|-------------|----------|------|-------|
| S | 38 cm | 23 | 13 | 299 |
| **M** | **42 cm** | **25** | **12** | **300** |
| L | 46 cm | 27 | 11 | 297 |
| XL | 50 cm | 30 | 10 | 300 |

Update `MATRIX_W` and `MATRIX_H` in `config.h` to match your shirt size.

---

### Step 2 — Mark the row lines

Turn the shirt inside-out. Using chalk or a temporary marker, draw 12 (or
however many) horizontal lines across the front panel, spaced evenly:

```
─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─   ← row 0  (top, near collar)
─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─   ← row 1
...
─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─   ← row 11 (bottom, near hem)
```

---

### Step 3 — Sew or glue the strip

**Option A — Sewing (most durable):**

Lay the strip along each marked row, LED-side facing **outward** toward the
fabric surface.  Hand-stitch across the strip backing every 5–6 cm using a
simple running stitch.  Keep stitches between LEDs, not through them.

**Option B — Fabric glue gun:**

Apply a thin bead of low-temperature hot glue along the strip backing and
press firmly against the fabric for 30 seconds.  Allow 15 min to cure before
routing the next row.

---

### Step 4 — Route the return bend

At the end of each row, the strip makes a U-turn to start the next row in the
opposite direction (serpentine). Leave a small loop (~2 cm) at each end so the
bend doesn't stress the strip solder pads. Tack the loop down with 2–3 stitches.

```
→ → → → → → → → → → → → →]
                            ↓  (loop / bend)
[← ← ← ← ← ← ← ← ← ← ← ←
↓
→ → → → → → → → → → → → →]
```

---

### Step 5 — Route the power and data wires

Use a seam ripper to open a small hole in the side hem seam. Thread the three
wires (5 V, GND, DIN) through the hem channel and out through a small exit
point near the waist, where the ESP32 and power bank sit in a small pocket or
belt pouch.

Reinforce the exit point with a grommet or a few tight stitches.

---

### Step 6 — Mount the ESP32

Place the ESP32 in a small zip-lock bag (protects from sweat) inside a side
pocket or a dedicated sewn pouch near the waist. Connect:

- `GPIO 18` → 330 Ω resistor → strip `DIN`
- `GND` → strip `GND`
- `VIN / 5V` → power bank output (5 V)
- Strip `+5V` → power bank output (5 V)

> Use a short USB-A to 5.5 mm barrel jack cable (or strip + solder directly)
> to connect the power bank to both the ESP32 and the strip in parallel.

---

### Step 7 — Test before final sewing

Before stitching everything closed:

1. Connect the power bank
2. Flash the sketch (see Setup below)
3. Watch the Serial Monitor — confirm WiFi and WebSocket connect
4. Start the Sentio backend
5. Put on the Muse headband and verify patterns change with emotion

Only after confirming everything works, finish securing the strip and close
any open seams.

---

## Patterns

| Emotion | Pattern | Visual on the shirt |
|---------|---------|---------------------|
| `calm` | **Fluid Waves** | Slow sine-wave ripples in steel-blue / powder-blue |
| `relaxed` | **Fluid Waves** | Slow ripples in mint / aqua green |
| `focused` | **Geometric Rings** | Sharp concentric rings in electric blue |
| `excited` | **Rhythmic Pulse** | Fast expanding rings in magenta / orange / amber |
| `stressed` | **Rhythmic Pulse** | Fast pulses in deep crimson / dark red |
| `neutral` | **Star Field** | Twinkling individual LEDs against dark fabric |
| no signal / idle | **Breathing** | Slow dim-pulse in blue — waiting for EEG |

> Brightness automatically scales with `signal_quality` and `confidence` from
> the EEG stream — the shirt literally glows brighter when the brain signal is cleaner.

---

## Setup

### 1 — Install Arduino IDE 2.x

Download from [arduino.cc/en/software](https://www.arduino.cc/en/software).

### 2 — Add ESP32 board support

`File → Preferences → Additional boards manager URLs`:

```
https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
```

`Tools → Board → Boards Manager` → search **esp32** → install **Espressif Systems** package.

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
// ── Strip layout ──────────────────────────────────────────────────────────────
#define LED_PIN        18        // GPIO pin → 330 Ω → DIN
#define MATRIX_W       25        // LEDs per row (adjust to your shirt width)
#define MATRIX_H       12        // number of rows (adjust to your shirt height)
// NUM_LEDS = MATRIX_W × MATRIX_H — must equal your actual LED count

// ── Brightness ────────────────────────────────────────────────────────────────
#define MAX_BRIGHTNESS 60        // 60 = safe on USB bank · great through fabric

// ── WiFi ─────────────────────────────────────────────────────────────────────
#define WIFI_AUTH_MODE 0         // 0 = WPA2 personal   1 = WPA2-Enterprise
#define WIFI_SSID      "YourNetwork"
#define WIFI_PASSWORD  "YourPassword"

// ── Backend ───────────────────────────────────────────────────────────────────
#define WS_HOST  "192.168.1.100" // IP of the machine running the Sentio backend
#define WS_PORT  8000
```

**Finding the backend machine IP:**

| OS | Command |
|----|---------|
| Windows | `ipconfig` → IPv4 Address |
| macOS | `ifconfig en0` → `inet` line |
| Linux | `ip a` → `inet` line |

**Using a phone hotspot for a demo:**
Connect both the laptop (running the backend) and the ESP32 to your phone's
hotspot. Use the laptop's hotspot-assigned IP as `WS_HOST`.

**WPA2-Enterprise (university networks):**  
Set `WIFI_AUTH_MODE 1` and fill in `WIFI_USERNAME`.

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

Open Serial Monitor at **115200 baud**:

```
╔══════════════════════════════════════╗
║  Sentio LED T-Shirt  25×12 (300 LEDs) ║
╚══════════════════════════════════════╝
[WiFi] Connected  IP=192.168.1.42  RSSI=-52 dBm
[WS]   Connected → ws://192.168.1.100:8000/ws/brain-stream
[EEG]  calm       pattern=fluid      α=0.65 β=0.18 θ=0.23 γ=0.06  Q=87  conf=0.84
[EEG]  focused    pattern=geometric  α=0.30 β=0.48 θ=0.12 γ=0.09  Q=91  conf=0.79
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Wrong colours (e.g. red shows as green) | Change `COLOR_ORDER GRB` → `RGB` in `config.h` |
| Pattern is upside-down | Toggle `MATRIX_FLIP_Y true` in `config.h` |
| Pattern is horizontally mirrored | Toggle `MATRIX_SERPENTINE` in `config.h` |
| Far end of strip is dim | Add a power injection point at the strip end (see Wiring) |
| Only idle breathing, no patterns | Check backend is running; verify `WS_HOST`; open Serial Monitor |
| WiFi won't connect | Double-check SSID / password; try phone hotspot; for enterprise set `WIFI_AUTH_MODE 1` |
| `fatal error: esp_eap_client.h` | Update ESP32 board package to latest version in Boards Manager |
| Flickering | Add 330 Ω on data line; add 470 µF cap at strip start; use thicker power wires |
| Shirt gets warm | Reduce `MAX_BRIGHTNESS`; ensure power supply can handle the current |
| Strip won't bend smoothly | Use silicone-insulated wire at corners; leave 2 cm loop at each row end |
| Power bank cuts out | Bank's low-current protection activates — add a small load resistor (100 Ω / 1 W) or use a bank without auto-off |
