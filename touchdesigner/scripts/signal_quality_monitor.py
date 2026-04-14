"""
signal_quality_monitor.py — Sentio TouchDesigner
==================================================
Place in the main Execute DAT (execDat) with Frame Start = On.
Runs SECOND in the frame pipeline (after signal_processor).

Tracks signal quality trends over a rolling window, classifies the
connection into one of four states, and manages the visual fallback
mode when the EEG signal is lost or degraded.

States:
    good          quality >= 0.70   — full live operation
    degraded      quality >= 0.40   — hold last-good values, warn in TextPort
    critical      quality >= 0.15   — enter fallback visual mode
    disconnected  quality <  0.15   — full fallback, log disconnect event

Operators driven:
    sentio_params  — writes 'mode' ('live' | 'fallback') and 'signal_state'
    noise1         — gentle idle animation during fallback
    bloom1         — softer glow during fallback
    hsvAdjust1     — desaturates during fallback
"""

from collections import deque

# ── Quality history ───────────────────────────────────────────────────────────
_WINDOW_FRAMES   = 180           # 3 s at 60 fps
_CHECK_INTERVAL  = 30            # evaluate every N frames (~0.5 s)
_quality_history = deque(maxlen=_WINDOW_FRAMES)

# ── State machine ─────────────────────────────────────────────────────────────
_current_state   = "good"        # 'good' | 'degraded' | 'critical' | 'disconnected'
_mode            = "live"        # 'live' | 'fallback'
_disconnect_time = None          # absTime.seconds when disconnect detected
_last_check      = 0             # last frame we ran the evaluation

# Pre-fallback snapshot (restore when signal returns)
_pre_fallback    = {}

# Thresholds
QUALITY_GOOD        = 0.70
QUALITY_DEGRADED    = 0.40
QUALITY_CRITICAL    = 0.15

# Hysteresis: must hold ABOVE threshold for N frames before leaving a bad state
_RECOVER_FRAMES  = 90   # 1.5 s of good quality before we call it recovered
_good_frame_count = 0


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


def _write(table, key, value):
    if table is None:
        return
    cell = table.findCell(str(key), col=0)
    if cell is not None:
        table[cell.row, 1] = value
    else:
        table.appendRow([key, value])


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


# ── State classification ──────────────────────────────────────────────────────

def _classify(quality):
    if quality >= QUALITY_GOOD:
        return "good"
    elif quality >= QUALITY_DEGRADED:
        return "degraded"
    elif quality >= QUALITY_CRITICAL:
        return "critical"
    else:
        return "disconnected"


def _mean_quality():
    if not _quality_history:
        return 1.0
    return sum(_quality_history) / len(_quality_history)


def _min_quality():
    if not _quality_history:
        return 1.0
    return min(_quality_history)


# ── Fallback visual mode ──────────────────────────────────────────────────────

def _snapshot_visual_state():
    """
    Save current operator parameter values before entering fallback
    so we can restore them when signal returns.
    """
    global _pre_fallback
    snap = {}

    noise = op("noise1")
    if noise:
        try:
            snap["noise_period"] = noise.par.period.val
            snap["noise_amp"]    = noise.par.amp.val
        except Exception:
            pass

    bloom = op("bloom1")
    if bloom:
        try:
            snap["bloom_threshold"] = bloom.par.threshold.val
        except Exception:
            pass

    hsv = op("hsvAdjust1")
    if hsv:
        try:
            snap["satmult"] = hsv.par.satmult.val
        except Exception:
            pass

    _pre_fallback = snap


def enter_fallback_mode():
    """
    Switch to safe idle visuals. Called once when state goes critical/disconnected.
    """
    global _mode
    if _mode == "fallback":
        return   # already in fallback

    _snapshot_visual_state()
    _mode = "fallback"

    table = _table()
    if table:
        _write(table, "mode", "fallback")

    # Apply gentle idle visual state
    _set_par("noise1",      "period",    10.0)
    _set_par("noise1",      "amp",       0.08)
    _set_par("bloom1",      "threshold", 0.85)
    _set_par("hsvAdjust1",  "satmult",   0.20)

    debug("[signal_quality_monitor] ⚠ Entered FALLBACK mode — signal lost")


def exit_fallback_mode():
    """
    Restore pre-fallback parameters. Called once when signal recovers.
    """
    global _mode, _pre_fallback
    if _mode == "live":
        return

    _mode = "live"

    table = _table()
    if table:
        _write(table, "mode", "live")

    # Restore saved values
    if _pre_fallback:
        _set_par("noise1",     "period",    _pre_fallback.get("noise_period", 6.0))
        _set_par("noise1",     "amp",       _pre_fallback.get("noise_amp",    0.45))
        _set_par("bloom1",     "threshold", _pre_fallback.get("bloom_threshold", 0.65))
        _set_par("hsvAdjust1", "satmult",   _pre_fallback.get("satmult", 1.0))
        _pre_fallback = {}

    debug("[signal_quality_monitor] ✓ Exited fallback — signal recovered")


# ── State transition handler ──────────────────────────────────────────────────

def _handle_state_change(old_state, new_state):
    """Log and act on state transitions."""
    if old_state == new_state:
        return

    ts = absTime.seconds
    msg = f"[signal_quality_monitor] Signal state: {old_state.upper()} → {new_state.upper()} @ t={ts:.1f}s"
    debug(msg)

    if new_state in ("critical", "disconnected"):
        enter_fallback_mode()
    elif new_state in ("good", "degraded") and old_state in ("critical", "disconnected"):
        exit_fallback_mode()


# ── Main entry point ──────────────────────────────────────────────────────────

def onFrameStart(frame):
    """
    Called every frame. Gates evaluation to every _CHECK_INTERVAL frames.
    """
    global _current_state, _last_check, _good_frame_count, _disconnect_time

    table = _table()
    quality = _read(table, "signal_quality", 1.0)

    # Always update history
    _quality_history.append(quality)

    # Gate: only evaluate every N frames
    if frame - _last_check < _CHECK_INTERVAL:
        return
    _last_check = frame

    mean_q = _mean_quality()
    min_q  = _min_quality()

    # Use min quality for state classification (conservative)
    raw_state = _classify(min_q)

    # Hysteresis: require sustained good quality before exiting bad states
    if raw_state == "good":
        _good_frame_count += _CHECK_INTERVAL
    else:
        _good_frame_count = 0

    if _current_state in ("critical", "disconnected"):
        # Only recover after sustained good signal
        if _good_frame_count >= _RECOVER_FRAMES:
            new_state = raw_state
        else:
            new_state = _current_state   # hold bad state
    else:
        new_state = raw_state

    # Track disconnect time
    if new_state == "disconnected" and _disconnect_time is None:
        _disconnect_time = absTime.seconds
    elif new_state != "disconnected":
        _disconnect_time = None

    # Handle transition
    _handle_state_change(_current_state, new_state)
    _current_state = new_state

    # Write state to table
    if table:
        _write(table, "signal_state", _current_state)
        _write(table, "quality_mean", round(mean_q, 3))
        _write(table, "quality_min",  round(min_q, 3))


# ── Public accessors ──────────────────────────────────────────────────────────

def get_current_state():
    """Return current state string: 'good' | 'degraded' | 'critical' | 'disconnected'"""
    return _current_state


def get_current_mode():
    """Return current mode string: 'live' | 'fallback'"""
    return _mode


def get_quality_stats():
    """Return dict with mean, min, and current window size."""
    return {
        "mean":         _mean_quality(),
        "min":          _min_quality(),
        "window_size":  len(_quality_history),
        "state":        _current_state,
        "mode":         _mode,
    }
