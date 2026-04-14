"""
particle_controller.py — Sentio TouchDesigner
===============================================
Place in the main Execute DAT (execDat) with Frame Start = On.
Runs AFTER param_handler in the frame pipeline.

Controls the Particle SOP and its Geometry/Render chain based on
processed EEG signals and the active emotion preset. Maps band
energies to: birth rate, lifespan, mass, turbulence, and drag.

TD Operators driven:
    particles1  — Particle SOP
    geo1        — Geometry COMP containing the particle SOP
    render1     — Render TOP that renders the particle layer
    null_chop   — reads smoothed band values
    sentio_params — reads preset_particle_rate and proc_* values
"""

import math

# ── Smoothed particle parameter state ─────────────────────────────────────────
_pp = {
    "birth_rate":   80.0,    # particles / second
    "lifespan":     2.0,     # seconds
    "mass":         0.5,     # arbitrary TD units
    "turbulence":   0.3,
    "drag":         0.4,
    "point_size":   3.0,     # render point size
    "opacity":      0.75,
}

SMOOTH_FAST   = 0.18
SMOOTH_MEDIUM = 0.07
SMOOTH_SLOW   = 0.03

# Birth-rate limits
BIRTH_MIN = 10.0
BIRTH_MAX = 900.0

# Lifespan limits (seconds)
LIFE_MIN = 0.5
LIFE_MAX = 6.0


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


def _lerp(a, b, t):
    return a + (b - a) * t


def _smooth(current, target, factor):
    return _lerp(current, target, factor)


def _clamp(val, lo, hi):
    return max(lo, min(hi, val))


def _pow(x, g):
    return _clamp(x, 0.0, 1.0) ** g


def _set_par(op_name, par_name, value):
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


# ── Band → particle parameter mappings ───────────────────────────────────────

def map_energy_to_birthrate(alpha, beta, gamma, preset_rate):
    """
    Particle birth rate is driven by a weighted mix of band energies.

    - Gamma dominates burst activity (peak focus moments)
    - Beta contributes continuous mid-level activity
    - Alpha inversely suppresses rate (calm = fewer sparks)
    - Preset rate (from emotion_mapper) sets the baseline
    """
    raw = (
        gamma * 0.50 +
        beta  * 0.30 +
        (1.0 - alpha) * 0.20
    )
    # Scale raw [0,1] to actual rate range, modulated by emotion preset
    baseline = _lerp(BIRTH_MIN, BIRTH_MAX, preset_rate)
    rate     = _lerp(BIRTH_MIN, baseline * 1.6, _pow(raw, 1.4))
    return _clamp(rate, BIRTH_MIN, BIRTH_MAX)


def map_theta_to_lifespan(theta):
    """
    High theta (meditative) → long lifespan: particles drift slowly and persist.
    Low theta (active)      → short lifespan: rapid turnover, flickering.
    """
    return _lerp(LIFE_MIN, LIFE_MAX, _pow(theta, 0.8))


def map_complexity_to_turbulence(complexity):
    """
    Pattern complexity directly maps to Particle SOP turbulence force.
    High complexity → chaotic particle trajectories.
    """
    return _lerp(0.05, 1.20, _pow(complexity, 1.2))


def map_delta_to_drag(delta):
    """
    Delta (deep background oscillation) drives drag / mass.
    High delta → heavy slow particles; low delta → lightweight fast sparks.
    """
    mass = _lerp(0.15, 1.20, _pow(delta, 0.9))
    drag = _lerp(0.10, 0.80, _pow(delta, 0.7))
    return mass, drag


def map_arousal_to_opacity(arousal, confidence):
    """
    Overall arousal (beta+gamma blend) scales particle opacity.
    Confidence modulates the range — high confidence = full dynamic range.
    """
    base    = _lerp(0.40, 0.95, _pow(arousal, 1.3))
    range_  = _lerp(0.5, 1.0, confidence)
    return _clamp(base * range_, 0.25, 1.0)


def map_engagement_to_size(engagement):
    """
    Engagement index (beta/alpha ratio) controls point sprite size.
    Focused states produce smaller, denser sparks.
    """
    return _lerp(5.0, 1.5, _pow(engagement, 1.5))


# ── Apply to operators ────────────────────────────────────────────────────────

def _apply_to_operators():
    """Write all smoothed particle parameters to TouchDesigner operators."""

    # ── Particle SOP ──────────────────────────────────────────────────────────
    _set_par("particles1", "birthrate",   _pp["birth_rate"])
    _set_par("particles1", "life",        _pp["lifespan"])
    _set_par("particles1", "mass",        _pp["mass"])
    _set_par("particles1", "turbulence",  _pp["turbulence"])
    _set_par("particles1", "drag",        _pp["drag"])

    # ── Render TOP — point sprite appearance ──────────────────────────────────
    _set_par("render1", "pointsize",      _clamp(_pp["point_size"], 1.0, 8.0))

    # ── Geometry COMP — opacity of the particle render layer ─────────────────
    _set_par("geo1",  "opacityr",         _pp["opacity"])
    _set_par("geo1",  "opacityg",         _pp["opacity"])
    _set_par("geo1",  "opacityb",         _pp["opacity"])


# ── Main entry point ──────────────────────────────────────────────────────────

def onFrameStart(frame):
    """
    Called every frame by the Execute DAT.

    Pipeline:
        1. Mode gate — skip if fallback
        2. Read band values + preset from sentio_params
        3. Compute target particle parameters
        4. Smooth toward targets
        5. Write to operators
    """
    global _pp

    table = _table()
    if table is None:
        return

    # 1. Mode gate
    mode = str(table[table.findCell("mode", col=0).row, 1]) if table.findCell("mode", col=0) else "live"
    if mode == "fallback":
        # During fallback: slow idle particle state
        _pp["birth_rate"] = _smooth(_pp["birth_rate"], 15.0, SMOOTH_SLOW)
        _pp["opacity"]    = _smooth(_pp["opacity"],     0.30, SMOOTH_SLOW)
        _apply_to_operators()
        return

    # 2. Read values
    alpha      = _read(table, "alpha",             0.50)
    beta       = _read(table, "beta",              0.20)
    theta      = _read(table, "theta",             0.20)
    gamma      = _read(table, "gamma",             0.05)
    delta      = _read(table, "delta",             0.05)
    complexity = _read(table, "complexity",        0.20)
    confidence = _read(table, "confidence",        1.00)
    arousal    = _read(table, "proc_arousal",      0.30)
    engagement = _read(table, "proc_engagement",   0.40)
    preset_rate= _read(table, "preset_particle_rate", 0.30)

    # 3. Compute targets
    birth_rate_t          = map_energy_to_birthrate(alpha, beta, gamma, preset_rate)
    lifespan_t            = map_theta_to_lifespan(theta)
    turbulence_t          = map_complexity_to_turbulence(complexity)
    mass_t, drag_t        = map_delta_to_drag(delta)
    opacity_t             = map_arousal_to_opacity(arousal, confidence)
    point_size_t          = map_engagement_to_size(engagement)

    # 4. Smooth
    _pp["birth_rate"]  = _smooth(_pp["birth_rate"],  birth_rate_t,  SMOOTH_FAST)
    _pp["lifespan"]    = _smooth(_pp["lifespan"],    lifespan_t,    SMOOTH_SLOW)
    _pp["mass"]        = _smooth(_pp["mass"],        mass_t,        SMOOTH_MEDIUM)
    _pp["turbulence"]  = _smooth(_pp["turbulence"],  turbulence_t,  SMOOTH_MEDIUM)
    _pp["drag"]        = _smooth(_pp["drag"],        drag_t,        SMOOTH_MEDIUM)
    _pp["opacity"]     = _smooth(_pp["opacity"],     opacity_t,     SMOOTH_MEDIUM)
    _pp["point_size"]  = _smooth(_pp["point_size"],  point_size_t,  SMOOTH_SLOW)

    # 5. Apply
    _apply_to_operators()


# ── Public accessor ───────────────────────────────────────────────────────────

def get_particle_params():
    """Return current smoothed particle parameter snapshot."""
    return dict(_pp)
