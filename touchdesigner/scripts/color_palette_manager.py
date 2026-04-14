"""
color_palette_manager.py — Sentio TouchDesigner
=================================================
Attach to a DAT Execute DAT connected to sentio_params.
Enable 'Table Change' so it fires when the color_palette row updates.
Also call tick_palette_transition(absTime.frame) from execDat every frame.

Parses the JSON hex palette from sentio_params, converts to HSV,
extracts the dominant hue and saturation range, and drives hsvAdjust1.
Also maintains a smooth blend when a new palette arrives mid-session.
"""

import json
import math

# ── Palette blend state ───────────────────────────────────────────────────────
_current_palette_hsv = []   # list of (h, s, v) tuples, normalised 0–1
_target_palette_hsv  = []
_blend_t             = 1.0  # 0 = start, 1 = finished
_blend_start_frame   = 0
_BLEND_FRAMES        = 120  # ~2 s at 60 fps

# Smoothed HSV output values
_smooth_hue    = 200.0 / 360.0   # 0–1
_smooth_sat    = 0.65

SMOOTH_FACTOR  = 0.04


# ── Colour math ───────────────────────────────────────────────────────────────

def hex_to_rgb(hex_str):
    """Convert '#RRGGBB' → (r, g, b) normalised 0–1."""
    h = hex_str.strip().lstrip("#")
    if len(h) != 6:
        return (0.5, 0.5, 0.5)
    try:
        r = int(h[0:2], 16) / 255.0
        g = int(h[2:4], 16) / 255.0
        b = int(h[4:6], 16) / 255.0
        return (r, g, b)
    except ValueError:
        return (0.5, 0.5, 0.5)


def rgb_to_hsv(r, g, b):
    """
    Convert normalised RGB → (h, s, v) all normalised 0–1.
    Pure Python implementation — no colorsys import needed.
    """
    cmax = max(r, g, b)
    cmin = min(r, g, b)
    delta = cmax - cmin

    # Hue
    if delta == 0:
        h = 0.0
    elif cmax == r:
        h = ((g - b) / delta) % 6.0
    elif cmax == g:
        h = (b - r) / delta + 2.0
    else:
        h = (r - g) / delta + 4.0
    h = (h / 6.0) % 1.0   # normalise to 0–1

    # Saturation
    s = 0.0 if cmax == 0 else delta / cmax

    # Value
    v = cmax

    return (h, s, v)


def parse_palette(json_str):
    """
    Deserialise JSON palette string → list of hex strings.
    Returns [] on any error.
    """
    if not json_str or json_str == "[]":
        return []
    try:
        data = json.loads(json_str)
        if isinstance(data, list):
            return [str(c) for c in data if str(c).startswith("#")]
        return []
    except (json.JSONDecodeError, TypeError):
        return []


def palette_to_hsv(hex_list):
    """Convert list of hex strings to list of (h, s, v) tuples."""
    return [rgb_to_hsv(*hex_to_rgb(h)) for h in hex_list]


def extract_dominant_hue(hsv_list):
    """
    Compute the circular mean hue from all palette colours,
    weighted by saturation (more saturated = more influence).
    Returns hue in degrees (0–360).
    """
    if not hsv_list:
        return 200.0  # default cyan-blue

    sin_sum = 0.0
    cos_sum = 0.0
    weight_sum = 0.0

    for h, s, v in hsv_list:
        angle = h * 2.0 * math.pi   # to radians
        weight = s * v + 0.01       # avoid zero weights
        sin_sum   += math.sin(angle) * weight
        cos_sum   += math.cos(angle) * weight
        weight_sum += weight

    if weight_sum == 0:
        return 200.0

    mean_angle = math.atan2(sin_sum / weight_sum, cos_sum / weight_sum)
    hue_deg = (math.degrees(mean_angle) % 360.0 + 360.0) % 360.0
    return hue_deg


def extract_saturation(hsv_list):
    """Return the mean saturation across all palette colours."""
    if not hsv_list:
        return 0.65
    return sum(s for _, s, _ in hsv_list) / len(hsv_list)


def interpolate_hsv_lists(from_list, to_list, t):
    """
    Blend two HSV palette lists element-wise.
    If sizes differ, the shorter list is padded with the last element.
    """
    if not from_list:
        return to_list
    if not to_list:
        return from_list

    n = max(len(from_list), len(to_list))
    result = []
    for i in range(n):
        a = from_list[min(i, len(from_list) - 1)]
        b = to_list[  min(i, len(to_list)   - 1)]
        # Hue: interpolate via shortest arc
        dh = b[0] - a[0]
        if dh > 0.5:
            dh -= 1.0
        elif dh < -0.5:
            dh += 1.0
        h = (a[0] + dh * t) % 1.0
        s = a[1] + (b[1] - a[1]) * t
        v = a[2] + (b[2] - a[2]) * t
        result.append((h, s, v))
    return result


# ── Operator writer ───────────────────────────────────────────────────────────

def _apply_to_operators(hue_deg, saturation):
    """Push computed hue and saturation to the visual operators."""
    hsv = op("hsvAdjust1")
    if hsv:
        try:
            hsv.par.hueshift = hue_deg / 360.0
            # Blend: emotion preset saturation × palette saturation
            table = op("sentio_params")
            preset_sat = 0.65
            if table:
                cell = table.findCell("preset_saturation", col=0)
                if cell:
                    try:
                        preset_sat = float(table[cell.row, 1])
                    except Exception:
                        pass
            hsv.par.satmult = max(0.1, min(2.0, (saturation * 0.4 + preset_sat * 0.6) + 0.3))
        except Exception:
            pass

    hue_chop = op("constant_hue")
    if hue_chop:
        try:
            hue_chop.par.value0 = hue_deg
        except Exception:
            pass


# ── Main callbacks ────────────────────────────────────────────────────────────

def onTableChange(dat):
    """
    Called by DAT Execute when sentio_params changes.
    Starts a palette blend if color_palette row was updated.
    """
    global _current_palette_hsv, _target_palette_hsv
    global _blend_t, _blend_start_frame

    table = op("sentio_params")
    if table is None:
        return

    cell = table.findCell("color_palette", col=0)
    if cell is None:
        return

    json_str = str(table[cell.row, 1])
    new_hex  = parse_palette(json_str)
    if not new_hex:
        return

    new_hsv = palette_to_hsv(new_hex)

    # Don't restart blend if palette hasn't meaningfully changed
    if new_hsv == _target_palette_hsv:
        return

    # Snapshot current blended state as the from-point
    if not _current_palette_hsv:
        _current_palette_hsv = list(new_hsv)
        _target_palette_hsv  = list(new_hsv)
        _blend_t = 1.0
        return

    _target_palette_hsv  = new_hsv
    _blend_start_frame   = absTime.frame
    _blend_t             = 0.0


def tick_palette_transition(frame):
    """
    Advance the palette blend and push current hue/sat to operators.
    Call from execDat.onFrameStart every frame.
    """
    global _blend_t, _smooth_hue, _smooth_sat, _current_palette_hsv

    if not _target_palette_hsv:
        return

    if _blend_t < 1.0:
        elapsed  = frame - _blend_start_frame
        _blend_t = min(1.0, elapsed / max(1, _BLEND_FRAMES))
        # Ease-in-out
        t = _blend_t * _blend_t * (3.0 - 2.0 * _blend_t)
        blended  = interpolate_hsv_lists(_current_palette_hsv, _target_palette_hsv, t)
        if _blend_t >= 1.0:
            _current_palette_hsv = list(_target_palette_hsv)
    else:
        blended = _current_palette_hsv if _current_palette_hsv else _target_palette_hsv

    if not blended:
        return

    target_hue = extract_dominant_hue(blended)   # 0–360 degrees
    target_sat = extract_saturation(blended)

    # Smooth hue (using circular diff to avoid wrap-around jumps)
    dh = target_hue - _smooth_hue * 360.0
    if dh > 180.0:
        dh -= 360.0
    elif dh < -180.0:
        dh += 360.0
    _smooth_hue = ((_smooth_hue * 360.0 + dh * SMOOTH_FACTOR) % 360.0) / 360.0
    _smooth_sat = _smooth_sat + (target_sat - _smooth_sat) * SMOOTH_FACTOR

    _apply_to_operators(_smooth_hue * 360.0, _smooth_sat)


# ── Public helpers ────────────────────────────────────────────────────────────

def get_dominant_hue():
    """Return current dominant hue in degrees (0–360)."""
    return _smooth_hue * 360.0


def get_current_palette_hex():
    """Return the current palette as a list of hex strings (approx)."""
    result = []
    for h, s, v in (_current_palette_hsv or []):
        r, g, b = _hsv_to_rgb(h, s, v)
        result.append("#{:02X}{:02X}{:02X}".format(
            int(r * 255), int(g * 255), int(b * 255)
        ))
    return result


def _hsv_to_rgb(h, s, v):
    """HSV → RGB (pure Python, no colorsys)."""
    if s == 0:
        return (v, v, v)
    i = int(h * 6)
    f = h * 6 - i
    p = v * (1 - s)
    q = v * (1 - f * s)
    t = v * (1 - (1 - f) * s)
    i = i % 6
    return [(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)][i]
