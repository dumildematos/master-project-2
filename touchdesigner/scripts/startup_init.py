"""
startup_init.py — Sentio TouchDesigner
========================================
Place in an Execute DAT with:
    Start       → On
    Frame Start → Off
    (All other callbacks Off)

Runs ONCE when the project loads. Responsibilities:
    1. Populate sentio_params Table DAT with safe default values
    2. Verify all expected operators are reachable
    3. Confirm OSCin CHOP is active on port 7000
    4. Write the neutral emotion preset so visual operators have
       valid values before the first OSC packet arrives
    5. Log a startup summary to the TouchDesigner TextPort

If any operator is missing, a clear warning is printed but the
project continues — a missing node is non-fatal at startup.
"""

import json

# ── Default values (safe visual state before first OSC data) ──────────────────
DEFAULTS = {
    # EEG bands
    "alpha":            0.50,
    "beta":             0.20,
    "theta":            0.20,
    "gamma":            0.05,
    "delta":            0.05,
    # Metadata
    "emotion":          "calm",
    "confidence":       1.00,
    "complexity":       0.20,
    "color_palette":    "[]",
    "signal_quality":   1.00,
    # State flags
    "mode":             "live",
    "signal_state":     "good",
    "quality_mean":     1.00,
    "quality_min":      1.00,
    # Processed derived values (written later by signal_processor)
    "proc_flow":        0.18,
    "proc_distortion":  0.12,
    "proc_engagement":  0.40,
    "proc_relaxation":  0.60,
    "proc_cognitive":   0.10,
    "proc_arousal":     0.25,
    "proc_theta_alpha": 0.40,
    # Emotion preset rows (calm defaults)
    "preset_hue_shift":          200.0,
    "preset_saturation":         0.65,
    "preset_noise_period":       7.5,
    "preset_blur_radius":        10.0,
    "preset_feedback_strength":  0.85,
    "preset_bloom_threshold":    0.70,
    "preset_particle_rate":      0.22,
    "preset_flow_speed":         0.14,
    "preset_distortion":         0.10,
}

# ── All operators that must exist for a healthy Sentio network ────────────────
REQUIRED_OPERATORS = [
    ("sentio_params",   "Table DAT — shared parameter store"),
    ("oscin1",          "OSC In CHOP — receives EEG stream"),
    ("filter_chop",     "Filter CHOP — signal smoothing"),
    ("null_chop",       "Null CHOP — reference point for expressions"),
    ("noise1",          "Noise TOP — fluid flow field base"),
    ("blur1",           "Blur TOP — edge softening"),
    ("composite1",      "Composite TOP — layer merge"),
    ("feedback1",       "Feedback TOP — trail persistence"),
    ("level1",          "Level TOP — brightness / gamma"),
    ("hsvAdjust1",      "HSV Adjust TOP — emotion colour"),
    ("bloom1",          "Bloom TOP — glow effect"),
    ("out1",            "Out TOP — final output"),
    ("particles1",      "Particle SOP — foreground sparks"),
    ("geo1",            "Geometry COMP — particle renderer"),
    ("render1",         "Render TOP — particle layer"),
    ("constant_hue",    "Constant CHOP — emotion hue value"),
    ("constant_flow",   "Constant CHOP — flow speed value"),
    ("constant_dist",   "Constant CHOP — distortion value"),
    ("stoner1",         "Stoner COMP — projection mapping"),
    ("window1",         "Window COMP — projector output"),
]

# ── Calm preset (written at startup so operators don't start at zero) ─────────
CALM_PRESET = {
    "preset_hue_shift":          200.0,
    "preset_saturation":         0.65,
    "preset_noise_period":       7.5,
    "preset_blur_radius":        10.0,
    "preset_feedback_strength":  0.85,
    "preset_bloom_threshold":    0.70,
    "preset_particle_rate":      0.22,
    "preset_flow_speed":         0.14,
    "preset_distortion":         0.10,
}


# ── Helpers ───────────────────────────────────────────────────────────────────

def _write_row(table, key, value):
    """Write or append a key/value row in the Table DAT."""
    cell = table.findCell(str(key), col=0)
    if cell is not None:
        table[cell.row, 1] = value
    else:
        table.appendRow([key, value])


def _set_par(op_name, par_name, value):
    o = op(op_name)
    if o is None:
        return False
    try:
        getattr(o.par, par_name).val = value
        return True
    except AttributeError:
        try:
            o.par[par_name] = value
            return True
        except Exception:
            return False


# ── Init steps ────────────────────────────────────────────────────────────────

def init_params_table():
    """
    Populate sentio_params with all expected rows at safe default values.
    Existing rows are overwritten; new rows are appended.
    """
    table = op("sentio_params")
    if table is None:
        debug("[startup_init] ✗ CRITICAL: 'sentio_params' Table DAT not found!")
        debug("[startup_init]   Create a Table DAT, rename it 'sentio_params', then reload.")
        return False

    for key, value in DEFAULTS.items():
        _write_row(table, key, value)

    debug(f"[startup_init] ✓ sentio_params initialised ({len(DEFAULTS)} rows)")
    return True


def init_osc_listener():
    """
    Verify OSCin CHOP is present and active.
    Does not change operator settings (those are set in the network directly).
    """
    osc = op("oscin1")
    if osc is None:
        debug("[startup_init] ✗ WARNING: 'oscin1' OSC In CHOP not found.")
        debug("[startup_init]   Add an OSC In CHOP named 'oscin1', port 7000, pattern /sentio/*")
        return False

    try:
        active = osc.par.active.val
        port   = osc.par.port.val
        if not active:
            debug("[startup_init] ⚠ WARNING: 'oscin1' is not Active. Enable it in the parameters.")
        if int(port) != 7000:
            debug(f"[startup_init] ⚠ WARNING: 'oscin1' is on port {port}, expected 7000.")
        debug(f"[startup_init] ✓ OSCin CHOP: port={port}, active={active}")
    except Exception as e:
        debug(f"[startup_init] ⚠ Could not read OSCin parameters: {e}")

    return True


def verify_operator_chain():
    """
    Walk the expected operator list and check each one exists.
    Prints a status summary — missing operators are warnings, not errors.
    """
    missing = []
    for op_name, description in REQUIRED_OPERATORS:
        o = op(op_name)
        if o is None:
            missing.append((op_name, description))

    if not missing:
        debug(f"[startup_init] ✓ All {len(REQUIRED_OPERATORS)} required operators found.")
    else:
        debug(f"[startup_init] ⚠ {len(missing)} operator(s) missing:")
        for op_name, desc in missing:
            debug(f"[startup_init]   ✗ '{op_name}'  ({desc})")

    return len(missing) == 0


def apply_default_preset():
    """
    Write the calm preset to both sentio_params and directly to operators.
    Ensures visual chain has valid values before first OSC packet.
    """
    table = op("sentio_params")
    if table is None:
        return

    for key, value in CALM_PRESET.items():
        _write_row(table, key, value)

    # Apply directly to operators (param_handler will smooth from here)
    _set_par("noise1",      "period",    CALM_PRESET["preset_noise_period"])
    _set_par("noise1",      "amp",       0.35)
    _set_par("blur1",       "size",      CALM_PRESET["preset_blur_radius"])
    _set_par("feedback1",   "feedback",  CALM_PRESET["preset_feedback_strength"])
    _set_par("level1",      "brightness",0.70)
    _set_par("hsvAdjust1",  "hueshift",  CALM_PRESET["preset_hue_shift"] / 360.0)
    _set_par("hsvAdjust1",  "satmult",   CALM_PRESET["preset_saturation"] + 0.3)
    _set_par("bloom1",      "threshold", CALM_PRESET["preset_bloom_threshold"])
    _set_par("particles1",  "birthrate", 80.0)
    _set_par("particles1",  "life",      2.0)

    # Constant CHOPs
    for chop_name, val in [
        ("constant_hue",  CALM_PRESET["preset_hue_shift"]),
        ("constant_flow", CALM_PRESET["preset_flow_speed"]),
        ("constant_dist", CALM_PRESET["preset_distortion"]),
    ]:
        o = op(chop_name)
        if o:
            try:
                o.par.value0 = val
            except Exception:
                pass

    debug("[startup_init] ✓ Default calm preset applied to operators.")


def log_startup_summary():
    """Print a formatted startup banner to the TouchDesigner TextPort."""
    sep = "─" * 60
    debug(sep)
    debug("  SENTIO — EEG-Driven Generative Fashion")
    debug("  TouchDesigner Network v1.0")
    debug(sep)
    try:
        debug(f"  TD Version    : {app.version}")
        debug(f"  Project file  : {project.name}")
        debug(f"  FPS target    : {project.cookRate}")
        debug(f"  Resolution    : {project.resolutionW} × {project.resolutionH}")
    except Exception:
        pass
    debug(f"  OSC Port      : 7000  →  /sentio/*")
    debug(f"  Backend URL   : http://127.0.0.1:8000")
    debug(f"  WebSocket     : ws://127.0.0.1:8000/ws/brain-stream")
    debug(sep)
    debug("  Start the backend:  cd backend && uvicorn main:app")
    debug("  Then open the React dashboard to begin a session.")
    debug(sep)


# ── Main onStart callback ─────────────────────────────────────────────────────

def onStart():
    """
    Execute DAT entry point — called once when the project loads.
    """
    log_startup_summary()

    ok_table   = init_params_table()
    ok_osc     = init_osc_listener()
    ok_chain   = verify_operator_chain()

    apply_default_preset()

    status = "READY" if (ok_table and ok_osc and ok_chain) else "READY (with warnings)"
    debug(f"[startup_init] ── Network status: {status} ──")


# ── Other Execute DAT callbacks (unused) ─────────────────────────────────────

def onExit():
    debug("[startup_init] Sentio project closing.")


def onFrameStart(frame):
    pass   # not used — startup only


def onFrameEnd(frame):
    pass


def onCreate():
    pass
