"""
build_network.py — Sentio TouchDesigner Network Builder
=========================================================
HOW TO USE:
    1. Open TouchDesigner (any blank project)
    2. Open the Textport:  Alt + T  (or  Dialogs > Textport)
    3. Paste this entire script into the Textport and press Enter
    4. The complete Sentio network will be built automatically
    5. Save:  Ctrl + S  →  name it  sentio.toe

Alternatively:
    • Add a Text DAT to your network
    • Paste this script into it
    • Right-click the Text DAT → Run Script
    • Then Ctrl+S to save as sentio.toe

What this script builds:
    ┌─ DATs ──────────────────────────────────────────────────┐
    │  sentio_params (Table DAT)    — shared parameter store  │
    │  oscin1        (OSC In CHOP)  — receives OSC on 7000    │
    │  5× Script DATs               — one per Python module   │
    │  2× Execute DATs              — startup + frame loop    │
    │  1× DAT Execute               — OSC callbacks           │
    └─────────────────────────────────────────────────────────┘
    ┌─ CHOPs ─────────────────────────────────────────────────┐
    │  filter_chop    Filter CHOP   — signal smoothing        │
    │  null_chop      Null CHOP     — expression anchor       │
    │  constant_hue   Constant CHOP — emotion hue (0–360)     │
    │  constant_flow  Constant CHOP — flow speed (0–1)        │
    │  constant_dist  Constant CHOP — distortion (0–1)        │
    └─────────────────────────────────────────────────────────┘
    ┌─ TOPs ──────────────────────────────────────────────────┐
    │  noise1         Noise TOP     — curl flow field         │
    │  remap1         Remap TOP     — normalise noise range   │
    │  blur1          Blur TOP      — edge softening          │
    │  feedback1      Feedback TOP  — trail persistence       │
    │  level1         Level TOP     — brightness / gamma      │
    │  composite1     Composite TOP — merge noise + particles │
    │  hsvAdjust1     HSV Adjust    — emotion colour shift    │
    │  bloom1         Bloom TOP     — luminous glow           │
    │  out1           Out TOP       — final output            │
    │  render1        Render TOP    — particle layer          │
    └─────────────────────────────────────────────────────────┘
    ┌─ SOPs / COMPs ──────────────────────────────────────────┐
    │  particles1     Particle SOP  — foreground sparks       │
    │  geo1           Geometry COMP — particle renderer       │
    │  cam1           Camera COMP   — render camera           │
    │  light1         Light COMP    — render light            │
    │  stoner1        Stoner COMP   — projection mapping      │
    │  window1        Window COMP   — projector fullscreen    │
    └─────────────────────────────────────────────────────────┘
"""

import os
import sys

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

# Path to the scripts folder (relative to this file, or absolute)
SCRIPTS_DIR = os.path.join(os.path.dirname(project.folder), "scripts")
if not os.path.isdir(SCRIPTS_DIR):
    # Fallback: look beside the .toe file
    SCRIPTS_DIR = os.path.join(project.folder, "scripts")

# Resolution
RES_W = 1920
RES_H = 1080

# Network layout: base positions (x, y) per operator group
# TouchDesigner network editor uses pixel coords; 150 px ≈ 1 node width
POS = {
    # DAT column (far left)
    "osc_callbacks_dat": (-1500,  200),
    "sentio_params":     (-1500, -100),
    "startup_exec":      (-1500, -350),
    "frame_exec":        (-1500, -550),
    "emotion_dat_exec":  (-1500,  450),
    "palette_dat_exec":  (-1500,  650),
    # Module Script DATs
    "mod_signal":        (-1800,  200),
    "mod_quality":       (-1800,    0),
    "mod_emotion":       (-1800, -200),
    "mod_palette":       (-1800, -400),
    "mod_param":         (-1800, -600),
    "mod_particle":      (-1800, -800),
    "mod_debug":         (-1800, -1000),
    "mod_proj":          (-1800, -1200),
    # CHOP column
    "oscin1":       (-900,  200),
    "filter_chop":  (-700,  200),
    "null_chop":    (-500,  200),
    "constant_hue": (-700,    0),
    "constant_flow":(-700, -150),
    "constant_dist":(-700, -300),
    # TOP chain (horizontal)
    "noise1":       (  0,    0),
    "remap1":       (200,    0),
    "blur1":        (400,    0),
    "composite1":   (700,    0),
    "feedback1":    (700, -200),
    "level1":       (900,    0),
    "hsvAdjust1":   (1100,   0),
    "bloom1":       (1300,   0),
    "out1":         (1500,   0),
    # Particle branch
    "particles1":   (300, -400),
    "geo1":         (500, -400),
    "render1":      (700, -400),
    "cam1":         (500, -600),
    "light1":       (700, -600),
    # Output
    "stoner1":      (1700,   0),
    "window1":      (1900,   0),
}


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

def log(msg):
    print(f"[Sentio Builder] {msg}")


def place(node, name):
    """Set node name and position from POS dict."""
    node.name = name
    if name in POS:
        node.nodeX, node.nodeY = POS[name]
    return node


def set_par(node, par_name, value):
    """Safely set a parameter by name."""
    try:
        node.par[par_name] = value
    except Exception as e:
        log(f"  ⚠ {node.name}.{par_name} = {value!r}  ({e})")


def wire(src, dst, src_out=0, dst_in=0):
    """Connect src output to dst input."""
    try:
        dst.inputConnectors[dst_in].connect(src.outputConnectors[src_out])
    except Exception as e:
        log(f"  ⚠ wire {src.name} → {dst.name}: {e}")


def load_script(dat_node, filename):
    """Load a .py file from SCRIPTS_DIR into a DAT node."""
    path = os.path.join(SCRIPTS_DIR, filename)
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                dat_node.text = f.read()
            log(f"  ✓ Loaded {filename} → {dat_node.name}")
        except Exception as e:
            log(f"  ✗ Could not load {filename}: {e}")
    else:
        log(f"  ⚠ Script not found: {path}")
        dat_node.text = f"# Script file not found: {filename}\n# Expected path: {path}\n"


def get_or_create(parent, op_type, name):
    """Return existing op if it exists, otherwise create it."""
    existing = parent.op(name)
    if existing is not None:
        log(f"  ~ Found existing: {name}")
        return existing
    return parent.create(op_type, name)


# ═══════════════════════════════════════════════════════════════════════════════
# BUILD FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

def build_dats(root):
    log("\n── Building DATs ─────────────────────────────────────")

    # ── sentio_params Table DAT ───────────────────────────────────────────────
    tbl = place(root.create(tableDAT, "sentio_params"), "sentio_params")
    tbl.clear()
    # Populate default rows (name, value)
    defaults = [
        ("alpha",            "0.50"),
        ("beta",             "0.20"),
        ("theta",            "0.20"),
        ("gamma",            "0.05"),
        ("delta",            "0.05"),
        ("emotion",          "calm"),
        ("confidence",       "1.00"),
        ("complexity",       "0.20"),
        ("color_palette",    "[]"),
        ("signal_quality",   "1.00"),
        ("mode",             "live"),
        ("signal_state",     "good"),
        ("quality_mean",     "1.00"),
        ("quality_min",      "1.00"),
        ("proc_flow",        "0.18"),
        ("proc_distortion",  "0.12"),
        ("proc_engagement",  "0.40"),
        ("proc_relaxation",  "0.60"),
        ("proc_cognitive",   "0.10"),
        ("proc_arousal",     "0.25"),
        ("proc_theta_alpha", "0.40"),
        ("preset_hue_shift",           "200.0"),
        ("preset_saturation",          "0.65"),
        ("preset_noise_period",        "7.5"),
        ("preset_blur_radius",         "10.0"),
        ("preset_feedback_strength",   "0.85"),
        ("preset_bloom_threshold",     "0.70"),
        ("preset_particle_rate",       "0.22"),
        ("preset_flow_speed",          "0.14"),
        ("preset_distortion",          "0.10"),
    ]
    for row in defaults:
        tbl.appendRow(list(row))
    log(f"  ✓ sentio_params Table DAT — {len(defaults)} rows")

    # ── Script DATs (module containers) ──────────────────────────────────────
    modules = [
        ("mod_signal_processor",   "signal_processor.py"),
        ("mod_signal_quality",     "signal_quality_monitor.py"),
        ("mod_emotion_mapper",     "emotion_mapper.py"),
        ("mod_color_palette",      "color_palette_manager.py"),
        ("mod_param_handler",      "param_handler.py"),
        ("mod_particle",           "particle_controller.py"),
        ("mod_debug",              "debug_utils.py"),
        ("mod_projection",         "projection_helpers.py"),
    ]
    pos_map = {
        "mod_signal_processor":  "mod_signal",
        "mod_signal_quality":    "mod_quality",
        "mod_emotion_mapper":    "mod_emotion",
        "mod_color_palette":     "mod_palette",
        "mod_param_handler":     "mod_param",
        "mod_particle":          "mod_particle",
        "mod_debug":             "mod_debug",
        "mod_projection":        "mod_proj",
    }
    for dat_name, script_file in modules:
        dat = root.create(textDAT, dat_name)
        dat.name = dat_name
        if dat_name in pos_map:
            key = pos_map[dat_name]
            if key in POS:
                dat.nodeX, dat.nodeY = POS[key]
        load_script(dat, script_file)

    # ── Startup Execute DAT ───────────────────────────────────────────────────
    startup = place(root.create(executeDAT, "startup_exec"), "startup_exec")
    startup.par.framestart = 0
    startup.par.start      = 1
    startup.par.exit       = 1
    load_script(startup, "startup_init.py")
    log("  ✓ startup_exec Execute DAT")

    # ── Main Frame Execute DAT ────────────────────────────────────────────────
    frame_exec = place(root.create(executeDAT, "execDat"), "frame_exec")
    frame_exec.par.framestart = 1
    frame_exec.par.start      = 0
    frame_exec.par.exit       = 0
    load_script(frame_exec, "execute_dat.py")
    log("  ✓ execDat Execute DAT (frame loop)")

    # ── DAT Execute for OSC callbacks ─────────────────────────────────────────
    osc_dat_exec = place(root.create(datexecuteDAT, "osc_dat_exec"), "osc_callbacks_dat")
    load_script(osc_dat_exec, "osc_callbacks.py")
    log("  ✓ osc_dat_exec DAT Execute")

    # ── DAT Execute for emotion_mapper (table change) ─────────────────────────
    em_dat_exec = place(root.create(datexecuteDAT, "emotion_dat_exec"), "emotion_dat_exec")
    em_dat_exec.par.tablechange = 1
    # Inline the onTableChange call
    em_dat_exec.text = (
        "def onTableChange(dat):\n"
        "    mod = op('mod_emotion_mapper')\n"
        "    if mod: mod.module.onTableChange(dat)\n"
    )
    log("  ✓ emotion_dat_exec DAT Execute (table change)")

    # ── DAT Execute for color_palette_manager (table change) ─────────────────
    pal_dat_exec = place(root.create(datexecuteDAT, "palette_dat_exec"), "palette_dat_exec")
    pal_dat_exec.par.tablechange = 1
    pal_dat_exec.text = (
        "def onTableChange(dat):\n"
        "    mod = op('mod_color_palette')\n"
        "    if mod: mod.module.onTableChange(dat)\n"
    )
    log("  ✓ palette_dat_exec DAT Execute (table change)")

    # Wire DAT Executes to sentio_params
    try:
        em_dat_exec.inputConnectors[0].connect(tbl)
        pal_dat_exec.inputConnectors[0].connect(tbl)
        osc_dat_exec.inputConnectors[0].connect(root.op("oscin1") or tbl)
    except Exception:
        pass   # oscin1 may not exist yet — wired after CHOPs are created

    return tbl, osc_dat_exec


def build_chops(root):
    log("\n── Building CHOPs ────────────────────────────────────")

    # ── OSC In CHOP ──────────────────────────────────────────────────────────
    osc = place(root.create(oscchopCHOP, "oscin1"), "oscin1")
    set_par(osc, "port",      7000)
    set_par(osc, "address",   "/sentio/*")
    set_par(osc, "active",    1)
    log("  ✓ oscin1 OSC In CHOP — port 7000, /sentio/*")

    # Wire OSC callbacks DAT Execute to oscin1
    try:
        osc_dat = root.op("osc_dat_exec")
        if osc_dat:
            osc_dat.inputConnectors[0].connect(osc)
    except Exception:
        pass

    # ── Filter CHOP ──────────────────────────────────────────────────────────
    flt = place(root.create(filterCHOP, "filter_chop"), "filter_chop")
    set_par(flt, "type",   0)       # 0 = Gaussian
    set_par(flt, "width",  0.3)     # 0.3 second window
    wire(osc, flt)
    log("  ✓ filter_chop Filter CHOP — Gaussian 0.3s")

    # ── Null CHOP (reference anchor for expressions) ──────────────────────────
    null = place(root.create(nullCHOP, "null_chop"), "null_chop")
    wire(flt, null)
    log("  ✓ null_chop Null CHOP")

    # ── Constant CHOPs ────────────────────────────────────────────────────────
    c_hue = place(root.create(constantCHOP, "constant_hue"), "constant_hue")
    set_par(c_hue, "name0",   "hue")
    set_par(c_hue, "value0",  200.0)
    log("  ✓ constant_hue — hue = 200")

    c_flow = place(root.create(constantCHOP, "constant_flow"), "constant_flow")
    set_par(c_flow, "name0",  "flow")
    set_par(c_flow, "value0", 0.14)
    log("  ✓ constant_flow — flow = 0.14")

    c_dist = place(root.create(constantCHOP, "constant_dist"), "constant_dist")
    set_par(c_dist, "name0",  "dist")
    set_par(c_dist, "value0", 0.10)
    log("  ✓ constant_dist — dist = 0.10")

    return osc, flt, null


def build_tops(root):
    log("\n── Building TOPs ─────────────────────────────────────")

    # ── Noise TOP ─────────────────────────────────────────────────────────────
    noise = place(root.create(noiseTOP, "noise1"), "noise1")
    set_par(noise, "type",       3)       # 3 = Sparse
    set_par(noise, "period",     7.5)
    set_par(noise, "amp",        0.35)
    set_par(noise, "monochrome", 0)       # colour output
    set_par(noise, "resolutionw", RES_W)
    set_par(noise, "resolutionh", RES_H)
    # Animate Z translate via expression — driven by constant_flow CHOP
    try:
        noise.par.tz.expr = "absTime.seconds * op('constant_flow')['flow']"
        noise.par.tz.mode = ParMode.EXPRESSION
    except Exception:
        pass
    log("  ✓ noise1 Noise TOP (Sparse, animated Z)")

    # ── Remap TOP ─────────────────────────────────────────────────────────────
    remap = place(root.create(remapTOP, "remap1"), "remap1")
    set_par(remap, "resolutionw", RES_W)
    set_par(remap, "resolutionh", RES_H)
    wire(noise, remap)
    log("  ✓ remap1 Remap TOP")

    # ── Blur TOP ──────────────────────────────────────────────────────────────
    blur = place(root.create(blurTOP, "blur1"), "blur1")
    set_par(blur, "size",        10.0)
    set_par(blur, "resolutionw", RES_W)
    set_par(blur, "resolutionh", RES_H)
    wire(remap, blur)
    log("  ✓ blur1 Blur TOP — size 10")

    # ── Feedback TOP ──────────────────────────────────────────────────────────
    # Wired AFTER composite to create the loop — see below
    feedback = place(root.create(feedbackTOP, "feedback1"), "feedback1")
    set_par(feedback, "feedback",    0.85)
    set_par(feedback, "resolutionw", RES_W)
    set_par(feedback, "resolutionh", RES_H)
    log("  ✓ feedback1 Feedback TOP — feedback 0.85")

    # ── Composite TOP (blur + render + feedback) ──────────────────────────────
    comp = place(root.create(compositeTOP, "composite1"), "composite1")
    set_par(comp, "operand",     11)      # 11 = Screen blending
    set_par(comp, "resolutionw", RES_W)
    set_par(comp, "resolutionh", RES_H)
    wire(blur,     comp, dst_in=0)        # input 0: noise field
    wire(feedback, comp, dst_in=1)        # input 1: feedback loop
    log("  ✓ composite1 Composite TOP (Screen)")

    # ── Feedback loop: composite → feedback ───────────────────────────────────
    try:
        feedback.par.top = "composite1"
    except Exception:
        pass

    # ── Level TOP ─────────────────────────────────────────────────────────────
    level = place(root.create(levelTOP, "level1"), "level1")
    set_par(level, "brightness",  0.985)   # slight per-frame fade
    set_par(level, "gamma",       1.0)
    set_par(level, "resolutionw", RES_W)
    set_par(level, "resolutionh", RES_H)
    wire(comp, level)
    log("  ✓ level1 Level TOP — brightness 0.985")

    # ── HSV Adjust TOP ────────────────────────────────────────────────────────
    hsv = place(root.create(hsvAdjustTOP, "hsvAdjust1"), "hsvAdjust1")
    set_par(hsv, "hueshift",     200.0 / 360.0)   # calm blue hue
    set_par(hsv, "satmult",      1.0)
    set_par(hsv, "valuemult",    1.0)
    set_par(hsv, "resolutionw",  RES_W)
    set_par(hsv, "resolutionh",  RES_H)
    wire(level, hsv)
    log("  ✓ hsvAdjust1 HSV Adjust TOP — hue 200°")

    # ── Bloom TOP ─────────────────────────────────────────────────────────────
    bloom = place(root.create(bloomTOP, "bloom1"), "bloom1")
    set_par(bloom, "threshold",   0.65)
    set_par(bloom, "size",        0.35)
    set_par(bloom, "resolutionw", RES_W)
    set_par(bloom, "resolutionh", RES_H)
    wire(hsv, bloom)
    log("  ✓ bloom1 Bloom TOP — threshold 0.65")

    # ── Out TOP ───────────────────────────────────────────────────────────────
    out = place(root.create(outTOP, "out1"), "out1")
    set_par(out, "resolutionw", RES_W)
    set_par(out, "resolutionh", RES_H)
    wire(bloom, out)
    log("  ✓ out1 Out TOP")

    return noise, blur, comp, feedback, level, hsv, bloom, out


def build_particle_chain(root):
    log("\n── Building Particle Chain ───────────────────────────")

    # ── Particle SOP ─────────────────────────────────────────────────────────
    part = place(root.create(particleSOP, "particles1"), "particles1")
    set_par(part, "birthrate",  80.0)
    set_par(part, "life",       2.0)
    set_par(part, "mass",       0.5)
    set_par(part, "turbulence", 0.3)
    set_par(part, "drag",       0.4)
    log("  ✓ particles1 Particle SOP")

    # ── Camera COMP ──────────────────────────────────────────────────────────
    cam = place(root.create(cameraCOMP, "cam1"), "cam1")
    set_par(cam, "tz", 5.0)   # pull back to see particles
    log("  ✓ cam1 Camera COMP")

    # ── Light COMP ───────────────────────────────────────────────────────────
    light = place(root.create(lightCOMP, "light1"), "light1")
    set_par(light, "tx", 2.0)
    set_par(light, "ty", 3.0)
    set_par(light, "tz", 5.0)
    log("  ✓ light1 Light COMP")

    # ── Geometry COMP ────────────────────────────────────────────────────────
    geo = place(root.create(geometryCOMP, "geo1"), "geo1")
    # Connect particle SOP as geo's SOP input
    try:
        wire(part, geo)
    except Exception:
        try:
            geo.par.sop = "particles1"
        except Exception:
            pass
    log("  ✓ geo1 Geometry COMP")

    # ── Render TOP ────────────────────────────────────────────────────────────
    render = place(root.create(renderTOP, "render1"), "render1")
    set_par(render, "resolutionw", RES_W)
    set_par(render, "resolutionh", RES_H)
    set_par(render, "bgcolorr",    0.0)
    set_par(render, "bgcolorg",    0.0)
    set_par(render, "bgcolorb",    0.0)
    set_par(render, "bgcolora",    0.0)   # transparent background
    # Assign camera and light
    try:
        set_par(render, "camera", "cam1")
        set_par(render, "lights", "light1")
    except Exception:
        pass
    log("  ✓ render1 Render TOP — transparent background")

    # Wire render1 into composite1 as the particle layer (input 2)
    comp = root.op("composite1")
    if comp:
        try:
            render.outputConnectors[0].connect(comp.inputConnectors[2])
            log("  ✓ render1 → composite1 (input 2, Screen blend)")
        except Exception:
            log("  ⚠ Could not wire render1 → composite1 — wire manually")

    return part, geo, render


def build_output_chain(root):
    log("\n── Building Output Chain ─────────────────────────────")

    # ── Stoner COMP ──────────────────────────────────────────────────────────
    stoner = place(root.create(stonerCOMP, "stoner1"), "stoner1")
    # Wire Out TOP into Stoner input
    out_op = root.op("out1")
    if out_op:
        wire(out_op, stoner)
    log("  ✓ stoner1 Stoner COMP — connect after calibration")

    # ── Window COMP ──────────────────────────────────────────────────────────
    window = place(root.create(windowCOMP, "window1"), "window1")
    set_par(window, "winw",       RES_W)
    set_par(window, "winh",       RES_H)
    set_par(window, "monitor",    1)      # Display 2 (projector) — change if needed
    set_par(window, "fullscreen", 0)      # keep off until calibrated
    # Wire Stoner into Window
    wire(stoner, window)
    log(f"  ✓ window1 Window COMP — {RES_W}×{RES_H}, Display 2 (fullscreen=Off)")
    log("    ↳ Enable fullscreen AFTER calibrating Stoner corner-pins")

    return stoner, window


def apply_chop_expressions(root):
    """
    Apply CHOP reference expressions to TOP parameters so they respond
    live to EEG data. These are the connections that make the visual reactive.
    """
    log("\n── Applying Live EEG Expressions ────────────────────")

    def expr(node, par_name, expression):
        try:
            p = node.par[par_name]
            p.expr = expression
            p.mode = ParMode.EXPRESSION
            log(f"  ✓ {node.name}.{par_name} = {expression}")
        except Exception as e:
            log(f"  ⚠ {node.name}.{par_name}: {e}")

    noise   = root.op("noise1")
    blur    = root.op("blur1")
    level   = root.op("level1")
    hsv     = root.op("hsvAdjust1")
    bloom   = root.op("bloom1")
    fback   = root.op("feedback1")

    # Noise TOP — beta drives roughness, alpha drives amplitude
    if noise:
        expr(noise, "amp",    "me.fetch('alpha', 0.5) * 0.8 + 0.1")
        expr(noise, "period", "op('sentio_params')['preset_noise_period', 1]")

    # Blur TOP — driven by param_handler via preset_blur_radius
    if blur:
        expr(blur, "size", "float(op('sentio_params')['preset_blur_radius', 1])")

    # Feedback TOP — theta drives trail length
    if fback:
        expr(fback, "feedback",
             "1.0 - float(op('null_chop')['theta']) * 0.3"
             " if op('null_chop').numChans > 0 else 0.85")

    # Level TOP — delta drives overall brightness
    if level:
        expr(level, "brightness",
             "float(op('sentio_params')['proc_arousal', 1]) * 0.4 + 0.55")

    # HSV Adjust — hue driven by constant_hue CHOP
    if hsv:
        expr(hsv, "hueshift",
             "op('constant_hue')['hue'] / 360.0"
             " if op('constant_hue').numChans > 0 else 0.55")
        expr(hsv, "satmult",
             "float(op('sentio_params')['preset_saturation', 1]) + 0.3")

    # Bloom TOP — gamma drives bloom threshold
    if bloom:
        expr(bloom, "threshold",
             "float(op('sentio_params')['preset_bloom_threshold', 1])")
        expr(bloom, "size",
             "float(op('null_chop')['gamma']) * 0.5 + 0.2"
             " if op('null_chop').numChans > 0 else 0.35")


def add_annotations(root):
    """
    Add annotation notes to key areas of the network for documentation.
    """
    log("\n── Adding Network Annotations ────────────────────────")

    annotations = [
        (-1850, -300, 250, 1300,
         "PYTHON MODULES\nScript DATs loaded as modules.\nDo not rename these nodes."),
        (-1550,  -50, 250,  800,
         "CONTROL LAYER\nDAT Executes + Table DAT.\nAll scripts share sentio_params."),
        (-950,   150, 600,  200,
         "OSC SIGNAL CHAIN\nOSCin → Filter → Null\nport 7000 /sentio/*"),
        (  -50, -500, 900,  550,
         "VISUAL PIPELINE\nNoise → Remap → Blur →\nComposite + Feedback →\nLevel → HSV → Bloom → Out"),
        ( 200,  -700, 700,  350,
         "PARTICLE LAYER\nParticle SOP → Geo → Render\nBlended via Composite (Screen)"),
        (1650,   -50, 450,  200,
         "PROJECTION OUTPUT\nStoner COMP → Window COMP\nCalibrate before enabling fullscreen"),
    ]

    for x, y, w, h, text in annotations:
        try:
            note = root.create(annotationCOMP)
            note.nodeX = x
            note.nodeY = y
            note.nodeWidth  = w
            note.nodeHeight = h
            note.comment    = text
        except Exception:
            pass   # annotationCOMP may have a different name in some TD versions

    log("  ✓ Network annotations added")


def set_render_quality(root):
    """Set global render quality for all TOPs."""
    try:
        for top in root.findChildren(type=TOP, maxDepth=1):
            try:
                top.par.outputresolution = 0   # 0 = Use resolution/width/height
            except Exception:
                pass
    except Exception:
        pass


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN BUILD FUNCTION
# ═══════════════════════════════════════════════════════════════════════════════

def build_sentio_network():
    """
    Build the complete Sentio TouchDesigner network in the root component.
    Run this from the TouchDesigner Textport (Alt+T).
    """
    # Work inside /project1 (default root component)
    root = op("/project1")
    if root is None:
        root = op("/")
        log("⚠ /project1 not found — building in root (/)")

    log("═" * 60)
    log("  SENTIO Network Builder")
    log(f"  Scripts directory: {SCRIPTS_DIR}")
    log(f"  Output resolution: {RES_W}×{RES_H}")
    log("═" * 60)

    # ── Build in order ────────────────────────────────────────────────────────
    tbl, osc_dat_exec   = build_dats(root)
    osc, flt, null      = build_chops(root)
    noise, blur, comp, feedback, level, hsv, bloom, out = build_tops(root)
    part, geo, render   = build_particle_chain(root)
    stoner, window      = build_output_chain(root)
    apply_chop_expressions(root)
    add_annotations(root)

    # ── Wire any remaining DAT connections ───────────────────────────────────
    try:
        osc_dat_exec.inputConnectors[0].connect(osc)
    except Exception:
        pass

    # ── Final summary ─────────────────────────────────────────────────────────
    log("\n" + "═" * 60)
    log("  ✓ Sentio network built successfully!")
    log("═" * 60)
    log("")
    log("  NEXT STEPS:")
    log("  1.  Ctrl + S  →  save as  sentio.toe")
    log("  2.  Start the Python backend:")
    log("        cd backend && uvicorn main:app --reload")
    log("  3.  Open the React dashboard and start a session")
    log("  4.  Verify OSCin CHOP shows active (green LED)")
    log("  5.  Calibrate Stoner COMP corner-pins on the mannequin")
    log("  6.  Enable window1 fullscreen on the projector display")
    log("")
    log("  DEBUG (paste in Textport):")
    log("        import debug_utils as d; d.health_check()")
    log("        import debug_utils as d; d.snapshot()")
    log("        import projection_helpers as ph; ph.simulate_test_pattern('grid')")
    log("═" * 60)


# ── Entry point ───────────────────────────────────────────────────────────────
# This runs immediately when pasted into the Textport or executed as a script.
build_sentio_network()
