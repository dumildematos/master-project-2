"""
signal_processor.py — Sentio TouchDesigner
============================================
Place this in an Execute DAT (execDat) with Frame Start = On.

Reads raw EEG band values from 'sentio_params', applies quality-gated
exponential smoothing, computes derived ratios (engagement, relaxation,
cognitive load), and writes processed values to Constant CHOPs that
feed the visual operator chain.

Execution order: runs FIRST in the frame pipeline.
"""

# ── Smoothing state (persists across frames at module level) ──────────────────
_smoothed = {
    "alpha": 0.50,
    "beta":  0.20,
    "theta": 0.20,
    "gamma": 0.05,
    "delta": 0.05,
}

# Last-known-good snapshot (held during signal dropout)
_last_good = dict(_smoothed)

# Quality state machine
_quality_history = []   # rolling window of recent quality values
_QUALITY_WINDOW  = 90   # frames (~1.5 s at 60 fps)

# Smoothing coefficients: α = 1 - e^(-dt/τ)  approximated as fixed constants
SMOOTH_FAST   = 0.15
SMOOTH_MEDIUM = 0.06
SMOOTH_SLOW   = 0.025

# Quality thresholds
QUALITY_GOOD      = 0.70
QUALITY_DEGRADED  = 0.40
QUALITY_CRITICAL  = 0.15


# ── Helpers ───────────────────────────────────────────────────────────────────

def _table():
    return op("sentio_params")


def _read(table, key, default=0.0):
    """Safe read from Table DAT; returns default if row missing."""
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


def _write(table, key, value):
    if table is None:
        return
    cell = table.findCell(str(key), col=0)
    if cell is not None:
        table[cell.row, 1] = value
    else:
        table.appendRow([key, value])


def _lerp(a, b, t):
    return a + (b - a) * t


def _smooth(current, target, factor):
    return _lerp(current, target, factor)


def _clamp(val, lo, hi):
    return max(lo, min(hi, val))


# ── Quality gate ──────────────────────────────────────────────────────────────

def _update_quality_history(quality):
    global _quality_history
    _quality_history.append(quality)
    if len(_quality_history) > _QUALITY_WINDOW:
        _quality_history.pop(0)


def _get_quality_state(quality):
    """Classify current signal quality into a state string."""
    if quality >= QUALITY_GOOD:
        return "good"
    elif quality >= QUALITY_DEGRADED:
        return "degraded"
    elif quality >= QUALITY_CRITICAL:
        return "critical"
    else:
        return "disconnected"


def _apply_quality_gate(raw_bands, quality):
    """
    Return bands to use based on signal quality:
    - good / degraded: use live raw_bands
    - critical / disconnected: use last-known-good snapshot
    Also updates _last_good when quality is acceptable.
    """
    global _last_good
    state = _get_quality_state(quality)

    if state in ("good", "degraded"):
        # Fresh data — update snapshot
        _last_good = dict(raw_bands)
        return raw_bands, state
    else:
        # Signal loss — hold last-good
        return dict(_last_good), state


# ── Derived ratios ────────────────────────────────────────────────────────────

def _compute_ratios(bands):
    """
    Compute derived cognitive/emotional indices from band powers.

    Returns a dict with:
        engagement     = beta / (alpha + 0.001)      — attention level
        relaxation     = alpha / (alpha + beta + 0.001) — calm ratio
        cognitive_load = gamma * complexity           — mental effort
        theta_alpha    = theta / (alpha + 0.001)      — meditative depth
        arousal        = (beta + gamma) * 0.5         — overall arousal
    """
    a = bands["alpha"]
    b = bands["beta"]
    t = bands["theta"]
    g = bands["gamma"]
    # complexity lives in the table, not in bands dict
    table = _table()
    c = _read(table, "complexity", 0.2)

    return {
        "engagement":     _clamp(b / (a + 0.001), 0.0, 3.0) / 3.0,
        "relaxation":     _clamp(a / (a + b + 0.001), 0.0, 1.0),
        "cognitive_load": _clamp(g * c, 0.0, 1.0),
        "theta_alpha":    _clamp(t / (a + 0.001), 0.0, 2.0) / 2.0,
        "arousal":        _clamp((b + g) * 0.5, 0.0, 1.0),
    }


# ── Constant CHOP writers ─────────────────────────────────────────────────────

def _push_to_chop(op_name, channel, value):
    """Write a single-channel value to a Constant CHOP."""
    chop = op(op_name)
    if chop is None:
        return
    try:
        chop.par[channel] = value
    except Exception:
        pass   # channel may not exist on this CHOP yet — non-fatal


def _push_processed_values(smoothed, ratios, quality):
    """
    Push all processed values out to the CHOP/operator layer.

    Constant CHOPs exposed to visual operators:
        constant_flow  → ch0 = flow speed      (from beta + ratio blend)
        constant_dist  → ch0 = distortion amt  (from complexity + engagement)
        constant_hue   → managed by emotion_mapper, not here
    """
    flow = _clamp(
        smoothed["beta"] * 0.55 + ratios["engagement"] * 0.30 + smoothed["gamma"] * 0.15,
        0.0, 1.0
    )
    dist = _clamp(
        ratios["cognitive_load"] * 0.6 + smoothed["beta"] * 0.4,
        0.0, 1.0
    )

    _push_to_chop("constant_flow", "value0", flow)
    _push_to_chop("constant_dist", "value0", dist)

    # Write processed values back to sentio_params so other scripts can read them
    table = _table()
    if table:
        _write(table, "proc_flow",         flow)
        _write(table, "proc_distortion",   dist)
        _write(table, "proc_engagement",   ratios["engagement"])
        _write(table, "proc_relaxation",   ratios["relaxation"])
        _write(table, "proc_cognitive",    ratios["cognitive_load"])
        _write(table, "proc_arousal",      ratios["arousal"])
        _write(table, "proc_theta_alpha",  ratios["theta_alpha"])
        _write(table, "signal_state",      _get_quality_state(quality))


# ── Main entry point ──────────────────────────────────────────────────────────

def onFrameStart(frame):
    """
    Called every frame by the Execute DAT.
    Runs the full signal processing pipeline:
      1. Read raw values from sentio_params
      2. Apply quality gate (hold-last-good on dropout)
      3. Exponential smooth all bands
      4. Compute derived ratios
      5. Push to Constant CHOPs and back to sentio_params
    """
    global _smoothed

    table = _table()
    if table is None:
        return

    # 1. Read raw band values
    raw = {band: _read(table, band, _smoothed[band]) for band in _smoothed}
    quality = _read(table, "signal_quality", 1.0)

    # 2. Update quality history + apply gate
    _update_quality_history(quality)
    gated_bands, quality_state = _apply_quality_gate(raw, quality)

    # 3. Smooth: use faster smoothing when signal is live, slower in degraded
    smooth_factor = SMOOTH_FAST if quality_state == "good" else SMOOTH_SLOW
    for band in _smoothed:
        _smoothed[band] = _smooth(_smoothed[band], gated_bands[band], smooth_factor)

    # 4. Derived ratios
    ratios = _compute_ratios(_smoothed)

    # 5. Push to operators
    _push_processed_values(_smoothed, ratios, quality)


# ── Public accessors (used by other scripts via op('signal_processor').module) ─

def get_smoothed_bands():
    """Return current smoothed band dict — snapshot, not live reference."""
    return dict(_smoothed)


def get_quality_mean():
    """Return mean quality over the rolling window."""
    if not _quality_history:
        return 1.0
    return sum(_quality_history) / len(_quality_history)


def get_quality_state():
    table = _table()
    quality = _read(table, "signal_quality", 1.0) if table else 1.0
    return _get_quality_state(quality)
