"""
param_handler.py — Sentio TouchDesigner
=========================================
Place in the main Execute DAT (execDat) with Frame Start = On.
Runs AFTER signal_processor and emotion_mapper in the frame pipeline.

Reads processed values from sentio_params (band ratios + emotion preset rows)
and writes them to the visual operator chain:
    noise1       ← Noise TOP    (period, amplitude, translate Z)
    blur1        ← Blur TOP     (radius)
    level1       ← Level TOP    (brightness, gamma, opacity)
    hsvAdjust1   ← HSV Adjust   (hue offset, saturation)
    bloom1       ← Bloom TOP    (threshold, size)
    feedback1    ← Feedback TOP (feedback amount)
    constant_hue / constant_flow / constant_dist  ← CHOP constants

All parameter writes are guarded: if the signal_quality_monitor has set
mode = 'fallback', this script skips live updates and holds the fallback values.
"""

# ── Smoothing state for visual parameters ─────────────────────────────────────
_vp = {
    "hue_shift":          200.0,
    "saturation":         0.65,
    "noise_period":       7.5,
    "blur_radius":        10.0,
    "feedback_strength":  0.85,
    "bloom_threshold":    0.70,
    "particle_rate":      0.30,
    "flow_speed":         0.14,
    "distortion":         0.10,
    # Band-driven modifiers (computed per frame)
    "brightness":         0.70,
    "noise_amp":          0.45,
    "noise_translate_z":  0.0,
}

# Smoothing coefficients per parameter type
SMOOTH_SLOW   = 0.025
SMOOTH_MEDIUM = 0.055
SMOOTH_FAST   = 0.14


# ── Helpers ───────────────────────────────────────────────────────────────────

def _table():
    return op("sentio_params")


def _read(table, key, default=0.0):
    if table is None:
        return default
    cell = table.findCell(str(key), col=0)
    if cell is None:
        return default
    try:
        return float(table[cell.row, 1])
    except (ValueError, TypeError):
        return default


def _read_str(table, key, default=""):
    if table is None:
        return default
    cell = table.findCell(str(key), col=0)
    if cell is None:
        return default
    return str(table[cell.row, 1])


def _lerp(a, b, t):
    return a + (b - a) * t


def _smooth(current, target, factor):
    return _lerp(current, target, factor)


def _clamp(val, lo, hi):
    return max(lo, min(hi, val))


def _set_par(op_name, par_name, value):
    """Safely set a named parameter on an operator."""
    o = op(op_name)
    if o is None:
        return
    try:
        getattr(o.par, par_name).val = value
    except AttributeError:
        try:
            o.par[par_name] = value
        except Exception:
            pass


def _set_chop_value(op_name, value):
    """Set value0 on a single-channel Constant CHOP."""
    o = op(op_name)
    if o is None:
        return
    try:
        o.par.value0 = value
    except Exception:
        pass


# ── Nonlinear mapping curves ──────────────────────────────────────────────────

def _sigmoid(x, steepness=8.0, midpoint=0.5):
    """Sigmoid curve — emphasises extreme values, neutral near midpoint."""
    import math
    try:
        return 1.0 / (1.0 + math.exp(-steepness * (x - midpoint)))
    except OverflowError:
        return 1.0 if x > midpoint else 0.0


def _power_curve(x, gamma=2.2):
    """Power curve — similar to display gamma correction."""
    return _clamp(x, 0.0, 1.0) ** gamma


def _map_range(value, in_lo, in_hi, out_lo, out_hi):
    """Linear remap from one range to another."""
    t = _clamp((value - in_lo) / max(in_hi - in_lo, 0.0001), 0.0, 1.0)
    return _lerp(out_lo, out_hi, t)


# ── Per-band visual mappings ──────────────────────────────────────────────────

def _map_alpha(alpha, preset_period, preset_blur):
    """
    Alpha (8–13 Hz) — relaxed awareness.
    High alpha: wide soft slow forms. Low alpha: compact sharp shapes.
    """
    noise_period = _lerp(preset_period * 0.6, preset_period * 1.4, alpha)
    blur_mod     = _lerp(preset_blur   * 0.7, preset_blur   * 1.5, alpha)
    brightness   = _map_range(_power_curve(alpha, 1.5), 0.0, 1.0, 0.40, 0.90)
    return noise_period, blur_mod, brightness


def _map_beta(beta, preset_period):
    """
    Beta (13–30 Hz) — active thinking.
    High beta: rapid turbulent flow. Low beta: smooth laminar flow.
    """
    noise_amp    = _map_range(_sigmoid(beta), 0.0, 1.0, 0.10, 0.70)
    noise_period = _lerp(preset_period, preset_period * 0.35, _power_curve(beta, 1.8))
    return noise_amp, noise_period


def _map_theta(theta, preset_feedback):
    """
    Theta (4–8 Hz) — meditative / drowsy state.
    High theta: very long trails (high feedback), dreamlike persistence.
    """
    feedback = _clamp(
        _lerp(preset_feedback * 0.7, 0.97, _power_curve(theta, 1.4)),
        0.55, 0.97
    )
    return feedback


def _map_gamma(gamma, preset_bloom):
    """
    Gamma (30–100 Hz) — peak cognitive load / focus moments.
    High gamma: lower bloom threshold = more glow; sharper contrast.
    """
    bloom_threshold = _lerp(preset_bloom, preset_bloom * 0.35, _power_curve(gamma, 2.0))
    bloom_size      = _map_range(gamma, 0.0, 1.0, 0.25, 0.75)
    return bloom_threshold, bloom_size


def _map_delta(delta):
    """
    Delta (0.5–4 Hz) — slow deep background oscillation.
    Drives large-scale turbulence (translate Z speed on the Noise TOP).
    """
    translate_speed = _map_range(_power_curve(delta, 1.2), 0.0, 1.0, 0.02, 0.35)
    return translate_speed


# ── Main frame update ─────────────────────────────────────────────────────────

def onFrameStart(frame):
    """
    Called every frame by the Execute DAT.

    Pipeline:
        1. Check mode (skip if fallback)
        2. Read preset rows + processed band values
        3. Compute target visual parameters from per-band mappings
        4. Exponential smooth toward targets
        5. Write smoothed values to operators
    """
    global _vp

    table = _table()
    if table is None:
        return

    # 1. Mode gate — skip live updates during signal fallback
    mode = _read_str(table, "mode", "live")
    if mode == "fallback":
        return

    # 2. Read preset rows (written by emotion_mapper)
    preset_hue     = _read(table, "preset_hue_shift",       200.0)
    preset_sat     = _read(table, "preset_saturation",       0.65)
    preset_period  = _read(table, "preset_noise_period",     6.0)
    preset_blur    = _read(table, "preset_blur_radius",      8.0)
    preset_fb      = _read(table, "preset_feedback_strength",0.82)
    preset_bloom   = _read(table, "preset_bloom_threshold",  0.65)
    preset_flow    = _read(table, "preset_flow_speed",       0.18)

    # 3. Read processed band values (written by signal_processor)
    alpha    = _read(table, "alpha",    0.50)
    beta     = _read(table, "beta",     0.20)
    theta    = _read(table, "theta",    0.20)
    gamma    = _read(table, "gamma",    0.05)
    delta    = _read(table, "delta",    0.05)
    conf     = _read(table, "confidence", 1.0)

    # 4a. Compute targets from per-band mappings
    noise_period_alpha, blur_alpha, brightness = _map_alpha(alpha, preset_period, preset_blur)
    noise_amp, noise_period_beta               = _map_beta(beta, noise_period_alpha)
    feedback_target                            = _map_theta(theta, preset_fb)
    bloom_thresh, bloom_size                   = _map_gamma(gamma, preset_bloom)
    translate_speed                            = _map_delta(delta)

    # Merge: beta narrows the period further on top of alpha
    noise_period_final = _clamp(
        _lerp(noise_period_alpha, noise_period_beta, beta * 0.55),
        0.4, 12.0
    )
    # Confidence scales the overall visual intensity
    intensity_scale = _lerp(0.6, 1.0, conf)

    # 4b. Smooth each visual parameter toward its target
    _vp["hue_shift"]         = _smooth(_vp["hue_shift"],         preset_hue,           SMOOTH_SLOW)
    _vp["saturation"]        = _smooth(_vp["saturation"],         preset_sat * intensity_scale, SMOOTH_SLOW)
    _vp["noise_period"]      = _smooth(_vp["noise_period"],       noise_period_final,   SMOOTH_MEDIUM)
    _vp["noise_amp"]         = _smooth(_vp["noise_amp"],          noise_amp,            SMOOTH_FAST)
    _vp["blur_radius"]       = _smooth(_vp["blur_radius"],        blur_alpha,           SMOOTH_MEDIUM)
    _vp["feedback_strength"] = _smooth(_vp["feedback_strength"],  feedback_target,      SMOOTH_SLOW)
    _vp["bloom_threshold"]   = _smooth(_vp["bloom_threshold"],    bloom_thresh,         SMOOTH_MEDIUM)
    _vp["brightness"]        = _smooth(_vp["brightness"],         brightness * intensity_scale, SMOOTH_MEDIUM)
    _vp["noise_translate_z"] = _vp["noise_translate_z"] + translate_speed / max(project.fps, 1)
    _vp["flow_speed"]        = _smooth(_vp["flow_speed"],         preset_flow,          SMOOTH_SLOW)

    # 5. Write to operators
    _apply_to_operators()


def _apply_to_operators():
    """Push all smoothed visual parameters to the respective TD operators."""

    # ── Noise TOP ─────────────────────────────────────────────────────────────
    _set_par("noise1", "period",      _vp["noise_period"])
    _set_par("noise1", "amp",         _vp["noise_amp"])
    _set_par("noise1", "tz",          _vp["noise_translate_z"])

    # ── Blur TOP ──────────────────────────────────────────────────────────────
    _set_par("blur1",  "size",        _clamp(_vp["blur_radius"], 1.0, 20.0))

    # ── Feedback TOP ──────────────────────────────────────────────────────────
    _set_par("feedback1", "feedback", _clamp(_vp["feedback_strength"], 0.55, 0.97))

    # ── Level TOP ─────────────────────────────────────────────────────────────
    _set_par("level1", "brightness",  _clamp(_vp["brightness"],   0.30, 1.10))
    _set_par("level1", "gamma",       _clamp(_vp["brightness"] * 1.1, 0.5, 1.8))

    # ── HSV Adjust TOP ────────────────────────────────────────────────────────
    # Hue shift: TD expects 0–1 range (not 0–360)
    _set_par("hsvAdjust1", "hueshift", _vp["hue_shift"] / 360.0)
    _set_par("hsvAdjust1", "satmult",  _clamp(_vp["saturation"] + 0.3, 0.2, 1.8))

    # ── Bloom TOP ─────────────────────────────────────────────────────────────
    _set_par("bloom1", "threshold",   _clamp(_vp["bloom_threshold"], 0.15, 0.90))
    _set_par("bloom1", "size",        _clamp(_vp["noise_amp"] * 0.6 + 0.2, 0.1, 0.8))

    # ── CHOP constants (visual chain reads these via expressions) ─────────────
    _set_chop_value("constant_flow", _vp["flow_speed"])
    _set_chop_value("constant_dist", _vp["noise_amp"])
    _set_chop_value("constant_hue",  _vp["hue_shift"])


# ── Public accessor ───────────────────────────────────────────────────────────

def get_visual_params():
    """Return current smoothed visual parameter snapshot."""
    return dict(_vp)
