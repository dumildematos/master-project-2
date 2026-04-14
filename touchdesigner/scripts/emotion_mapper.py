"""
emotion_mapper.py — Sentio TouchDesigner
==========================================
Attach to a DAT Execute DAT connected to the sentio_params Table DAT.
Enable the 'Table Change' callback so it fires when the emotion row updates.
Also call tick_transition(absTime.frame) from the main Execute DAT every frame.

Translates the emotion string label + confidence float into a complete
visual preset dictionary, then blends smoothly from the current preset
to the new one over BLEND_SECONDS.

Preset rows written to sentio_params (prefixed 'preset_'):
    preset_hue_shift       float 0–360   base hue for HSV Adjust
    preset_saturation      float 0–1     colour saturation multiplier
    preset_noise_period    float         Noise TOP period
    preset_blur_radius     float px      Blur TOP radius
    preset_feedback_strength float 0–1   Feedback TOP feedback amount
    preset_bloom_threshold float 0–1     Bloom TOP threshold
    preset_particle_rate   float 0–1     normalised particle birth rate
    preset_flow_speed      float 0–1     flow animation speed
    preset_distortion      float 0–1     warp / distortion amount
"""

import json

# ── Blend state ───────────────────────────────────────────────────────────────
_blend_from       = None     # preset dict we're blending away from
_blend_to         = None     # preset dict we're blending toward
_blend_start_frame = 0
_blend_duration   = 150      # frames at 60 fps ≈ 2.5 s
_current_emotion  = "calm"
_current_preset   = None     # live interpolated preset dict


# ── Preset library ────────────────────────────────────────────────────────────

def build_preset_library():
    """
    Return the full emotion → visual preset dictionary.

    Each preset defines all parameters that the visual chain responds to.
    Values are intentionally distinct per emotion so transitions are visible.
    """
    return {
        # ── CALM ─────────────────────────────────────────────────────────────
        # Deep alpha dominance. Slow, wide, azure light masses.
        "calm": {
            "hue_shift":          200.0,
            "saturation":         0.65,
            "noise_period":       7.5,
            "blur_radius":        10.0,
            "feedback_strength":  0.85,
            "bloom_threshold":    0.70,
            "particle_rate":      0.22,
            "flow_speed":         0.14,
            "distortion":         0.10,
        },

        # ── FOCUSED ──────────────────────────────────────────────────────────
        # High beta. Sharp golden angular streams, tight structures.
        "focused": {
            "hue_shift":          42.0,
            "saturation":         0.90,
            "noise_period":       2.5,
            "blur_radius":        3.0,
            "feedback_strength":  0.62,
            "bloom_threshold":    0.38,
            "particle_rate":      0.65,
            "flow_speed":         0.55,
            "distortion":         0.30,
        },

        # ── STRESSED ─────────────────────────────────────────────────────────
        # Fragmented beta bursts. Crimson turbulent fractures.
        "stressed": {
            "hue_shift":          5.0,
            "saturation":         1.00,
            "noise_period":       1.2,
            "blur_radius":        1.5,
            "feedback_strength":  0.40,
            "bloom_threshold":    0.22,
            "particle_rate":      0.90,
            "flow_speed":         0.88,
            "distortion":         0.72,
        },

        # ── RELAXED ──────────────────────────────────────────────────────────
        # Theta-alpha blend. Teal-green dissolving edges, melting ribbons.
        "relaxed": {
            "hue_shift":          175.0,
            "saturation":         0.55,
            "noise_period":       9.0,
            "blur_radius":        14.0,
            "feedback_strength":  0.92,
            "bloom_threshold":    0.78,
            "particle_rate":      0.14,
            "flow_speed":         0.09,
            "distortion":         0.06,
        },

        # ── EXCITED ──────────────────────────────────────────────────────────
        # Gamma+beta surge. Violet-magenta expanding bursts.
        "excited": {
            "hue_shift":          285.0,
            "saturation":         0.95,
            "noise_period":       1.8,
            "blur_radius":        4.0,
            "feedback_strength":  0.52,
            "bloom_threshold":    0.28,
            "particle_rate":      0.80,
            "flow_speed":         0.75,
            "distortion":         0.55,
        },

        # ── NEUTRAL (default / idle) ──────────────────────────────────────────
        "neutral": {
            "hue_shift":          220.0,
            "saturation":         0.50,
            "noise_period":       5.0,
            "blur_radius":        8.0,
            "feedback_strength":  0.80,
            "bloom_threshold":    0.65,
            "particle_rate":      0.30,
            "flow_speed":         0.18,
            "distortion":         0.12,
        },
    }


_PRESETS = build_preset_library()


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


def _ease_in_out(t):
    """Cubic ease-in-out for smoother emotion transitions."""
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def blend_presets(from_p, to_p, t):
    """
    Linearly interpolate between two preset dicts.
    Returns a new dict with blended values.
    """
    t = _ease_in_out(t)
    result = {}
    for key in to_p:
        a = from_p.get(key, to_p[key])
        result[key] = _lerp(a, to_p[key], t)
    return result


def write_preset_to_table(table, preset):
    """Write all preset keys (prefixed 'preset_') into sentio_params."""
    for key, value in preset.items():
        _write(table, f"preset_{key}", value)

    # Also push hue directly to constant_hue CHOP for immediate effect
    hue_chop = op("constant_hue")
    if hue_chop:
        try:
            hue_chop.par.value0 = preset.get("hue_shift", 200.0)
        except Exception:
            pass


# ── Transition state machine ──────────────────────────────────────────────────

def start_transition(new_emotion, confidence):
    """
    Initiate a blend from the current preset to the preset for new_emotion.
    Minimum confidence threshold: 0.55 — below this, ignore the label.
    """
    global _blend_from, _blend_to, _blend_start_frame, _current_emotion, _current_preset

    if confidence < 0.55:
        return   # low confidence — do not commit to new emotion

    if new_emotion == _current_emotion:
        return   # already there — no transition needed

    if new_emotion not in _PRESETS:
        debug(f"[emotion_mapper] Unknown emotion preset '{new_emotion}' — ignored")
        return

    # Snapshot current blended state as the blend-from point
    if _current_preset is None:
        _current_preset = dict(_PRESETS.get(_current_emotion, _PRESETS["neutral"]))

    _blend_from        = dict(_current_preset)
    _blend_to          = dict(_PRESETS[new_emotion])
    _blend_start_frame = absTime.frame
    _current_emotion   = new_emotion

    debug(f"[emotion_mapper] Transition → {new_emotion} (confidence={confidence:.2f})")


def tick_transition(frame):
    """
    Advance the blend state machine by one frame.
    Call this from the Execute DAT's onFrameStart.
    """
    global _current_preset

    table = _table()
    if table is None:
        return

    if _blend_from is None or _blend_to is None:
        # No active transition — ensure defaults are written
        if _current_preset is None:
            _current_preset = dict(_PRESETS.get(_current_emotion, _PRESETS["neutral"]))
            write_preset_to_table(table, _current_preset)
        return

    elapsed = frame - _blend_start_frame
    t = min(1.0, elapsed / max(1, _blend_duration))

    _current_preset = blend_presets(_blend_from, _blend_to, t)
    write_preset_to_table(table, _current_preset)

    # Transition complete
    if t >= 1.0:
        _blend_from = None
        _blend_to   = None


# ── DAT Execute callbacks ─────────────────────────────────────────────────────

def onTableChange(dat):
    """
    Fired by DAT Execute when sentio_params changes.
    Reads the new emotion + confidence and starts a transition if needed.
    """
    table = _table()
    if table is None:
        return

    emotion    = _read_str(table, "emotion",    "neutral")
    confidence = _read(table,     "confidence", 1.0)

    start_transition(emotion, confidence)


# Called every frame from the main Execute DAT (execDat)
def onFrameStart_emotion(frame):
    """Alias for tick_transition — call this from execDat.onFrameStart."""
    tick_transition(frame)


# ── Public helpers ────────────────────────────────────────────────────────────

def get_current_preset():
    """Return the live interpolated preset dict (snapshot)."""
    return dict(_current_preset) if _current_preset else {}


def get_current_emotion():
    return _current_emotion


def get_all_presets():
    """Return the full preset library (for debug_utils)."""
    return dict(_PRESETS)
