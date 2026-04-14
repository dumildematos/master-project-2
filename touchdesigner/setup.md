# TouchDesigner Setup — Sentio

## Prerequisites
- TouchDesigner 2023.11 or later (free non-commercial licence is sufficient)
- Python 3.11 (bundled with TD — no separate install needed)
- Sentio backend running on port 8000 / OSC on port 7000

---

## Step 1 — OSC Input

1. Add an **OSC In DAT**
   - *Network Address* → `127.0.0.1`
   - *Port* → `7000`
   - *Active* → `On`
2. Add a **DAT Execute DAT**, connect it to the OSC In DAT
3. Paste the contents of `scripts/osc_callbacks.py` into the DAT Execute

---

## Step 2 — Parameter Table

1. Add a **Table DAT**, rename it `sentio_params`
2. Add these rows (col 0 = name, col 1 = value):

| name            | value |
|-----------------|-------|
| colorHue        | 120   |
| flowSpeed       | 0.35  |
| distortion      | 0.20  |
| particleDensity | 0.40  |
| brightness      | 0.65  |

---

## Step 3 — Frame Update Script

1. Add an **Execute DAT**
   - *Frame Start* → `On`
2. Paste the contents of `scripts/param_handler.py`
3. Adjust the `op("…")` paths to match your network layout

---

## Step 4 — Mannequin Geometry

1. Import your mannequin `.obj` → **File In SOP**
2. Add a **Subdivide SOP** (depth 2) for smooth deformation
3. Connect → **GLSL MAT**
   - *Vertex Shader*   → paste `shaders/cloth_vertex.glsl`
   - *Fragment Shader* → paste `shaders/cloth_fragment.glsl`
4. Add a **Constant CHOP** with channels:
   `uColorHue`, `uFlowSpeed`, `uDistortion`, `uBrightness`
   Connect it to the GLSL MAT uniform inputs

---

## Step 5 — Particle Overlay

1. Add a **Particle SOP** above the mannequin
2. Wire birth-rate from a **CHOP to SOP** reading `particleDensity`
   from `sentio_params`
3. Use a **Point Sprite TOP** or **Instancing** for rendering

---

## Step 6 — Shader Uniforms → CHOP

Connect the frame-update script outputs to shader uniforms via a
**Select CHOP** reading from `sentio_params`:

| Uniform          | Source channel  | Scale |
|------------------|-----------------|-------|
| `uColorHue`      | colorHue        | ÷ 360 |
| `uFlowSpeed`     | flowSpeed       | × 1   |
| `uDistortion`    | distortion      | × 1   |
| `uBrightness`    | brightness      | × 1   |
| `uTime`          | absTime:seconds | × 1   |

---

## Network Overview

```
OSC In DAT
    │  osc_callbacks.py
    ▼
sentio_params (Table DAT)
    │  param_handler.py  (Execute DAT, every frame)
    ├──────────────────────────────────────┐
    ▼                                      ▼
Cloth Geometry                        Particle SOP
  File In SOP                           birthrate
  → Subdivide SOP
  → GLSL MAT
      cloth_vertex.glsl
      cloth_fragment.glsl
    ▼
Render TOP → Out TOP
```
