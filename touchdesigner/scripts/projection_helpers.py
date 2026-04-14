"""
projection_helpers.py — Sentio TouchDesigner
=============================================
Utility functions for Stoner COMP projection mapping setup.
NOT called automatically — invoke from the TouchDesigner TextPort
or bind to keyboard shortcuts during installation/calibration.

Usage examples (paste into TD TextPort):
    import projection_helpers as ph
    ph.save_calibration()
    ph.load_calibration()
    ph.reset_to_identity()
    ph.set_output_resolution(1920, 1080)
    ph.print_calibration_state()
    ph.simulate_test_pattern("grid")
"""

import json
import os

# ── Config ────────────────────────────────────────────────────────────────────
STONER_OP   = "stoner1"
WINDOW_OP   = "window1"
OUT_OP      = "out1"
RENDER_OP   = "render1"

# Calibration file saved next to the .toe project file
CALIB_FILE  = "sentio_calibration.json"

# Named projection zones: zone_name → UV rect (x, y, w, h) in 0–1 space
_zones = {}


# ── Helpers ───────────────────────────────────────────────────────────────────

def _stoner():
    o = op(STONER_OP)
    if o is None:
        debug(f"[projection_helpers] ✗ '{STONER_OP}' not found. Add a Stoner COMP named '{STONER_OP}'.")
    return o


def _window():
    o = op(WINDOW_OP)
    if o is None:
        debug(f"[projection_helpers] ✗ '{WINDOW_OP}' not found.")
    return o


def _out():
    return op(OUT_OP)


def _project_path():
    """Return the directory containing the .toe file."""
    try:
        return os.path.dirname(project.folder)
    except Exception:
        return os.getcwd()


def _calib_path():
    return os.path.join(_project_path(), CALIB_FILE)


# ── Calibration persistence ───────────────────────────────────────────────────

def save_calibration(filepath=None):
    """
    Serialise Stoner COMP warp data to a JSON file.

    Saves:
        - All Stoner point positions (corner pins + any added mesh points)
        - Output resolution from Window COMP
        - Named zone registry

    Call this after every calibration session.
    """
    stoner = _stoner()
    if stoner is None:
        return

    path = filepath or _calib_path()

    # Collect Stoner warp points
    # Stoner stores points as a table accessible via stoner.points
    points = []
    try:
        for pt in stoner.points:
            points.append({
                "id":   pt.id,
                "u":    pt.u,
                "v":    pt.v,
                "tx":   pt.tx,
                "ty":   pt.ty,
            })
    except Exception as e:
        debug(f"[projection_helpers] ⚠ Could not read Stoner points: {e}")
        # Fallback: save parameter-based corner pins
        try:
            points = [{
                "corner": "tl", "tx": stoner.par.ulx.val, "ty": stoner.par.uly.val,
            }, {
                "corner": "tr", "tx": stoner.par.urx.val, "ty": stoner.par.ury.val,
            }, {
                "corner": "br", "tx": stoner.par.lrx.val, "ty": stoner.par.lry.val,
            }, {
                "corner": "bl", "tx": stoner.par.llx.val, "ty": stoner.par.lly.val,
            }]
        except Exception:
            points = []

    # Window resolution
    res = {}
    window = _window()
    if window:
        try:
            res = {"w": window.par.winw.val, "h": window.par.winh.val}
        except Exception:
            pass

    data = {
        "version":    "1.0",
        "project":    project.name if hasattr(project, "name") else "",
        "timestamp":  absTime.seconds,
        "points":     points,
        "resolution": res,
        "zones":      _zones,
    }

    try:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        debug(f"[projection_helpers] ✓ Calibration saved → {path}")
        debug(f"[projection_helpers]   {len(points)} warp point(s), resolution={res}")
    except OSError as e:
        debug(f"[projection_helpers] ✗ Save failed: {e}")


def load_calibration(filepath=None):
    """
    Restore Stoner warp state from a previously saved JSON file.
    Call this on project startup if a calibration file exists.
    """
    stoner = _stoner()
    if stoner is None:
        return

    path = filepath or _calib_path()

    if not os.path.exists(path):
        debug(f"[projection_helpers] ⚠ No calibration file at: {path}")
        debug("[projection_helpers]   Run save_calibration() after your first calibration.")
        return

    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        debug(f"[projection_helpers] ✗ Load failed: {e}")
        return

    points = data.get("points", [])
    zones  = data.get("zones",  {})

    # Restore corner pins (parameter-based fallback)
    corners = {p.get("corner"): p for p in points if "corner" in p}
    if corners:
        for corner, par_x, par_y in [
            ("tl", "ulx", "uly"), ("tr", "urx", "ury"),
            ("br", "lrx", "lry"), ("bl", "llx", "lly"),
        ]:
            if corner in corners:
                try:
                    stoner.par[par_x] = corners[corner]["tx"]
                    stoner.par[par_y] = corners[corner]["ty"]
                except Exception:
                    pass

    # Restore zone registry
    global _zones
    _zones.update(zones)

    # Restore resolution
    res = data.get("resolution", {})
    if res:
        set_output_resolution(res.get("w", 1920), res.get("h", 1080))

    debug(f"[projection_helpers] ✓ Calibration loaded from: {path}")
    debug(f"[projection_helpers]   {len(points)} point(s), {len(zones)} zone(s)")


# ── Corner-pin helpers ────────────────────────────────────────────────────────

def reset_to_identity(stoner_op=None):
    """
    Reset all Stoner COMP warp points to a flat identity transform.
    Use this to start calibration from scratch.
    """
    stoner = stoner_op or _stoner()
    if stoner is None:
        return

    # Standard identity corner-pin values (screen-space -1 to +1 coords)
    identity = {
        "ulx": -1.0, "uly":  1.0,   # top-left
        "urx":  1.0, "ury":  1.0,   # top-right
        "lrx":  1.0, "lry": -1.0,   # bottom-right
        "llx": -1.0, "lly": -1.0,   # bottom-left
    }
    for par_name, val in identity.items():
        try:
            stoner.par[par_name] = val
        except Exception:
            pass

    debug("[projection_helpers] ✓ Stoner reset to identity (flat rectangle).")


def nudge_corner(corner, dx=0.0, dy=0.0):
    """
    Nudge a corner-pin by a small offset for fine-tuning.

    corner: 'tl' | 'tr' | 'br' | 'bl'
    dx, dy: offset in normalised screen space (0.01 ≈ 1% of screen width)

    Example (TextPort):
        ph.nudge_corner('tl', dx=-0.005, dy=0.003)
    """
    stoner = _stoner()
    if stoner is None:
        return

    par_map = {
        "tl": ("ulx", "uly"),
        "tr": ("urx", "ury"),
        "br": ("lrx", "lry"),
        "bl": ("llx", "lly"),
    }
    if corner not in par_map:
        debug(f"[projection_helpers] Unknown corner '{corner}'. Use: tl, tr, br, bl")
        return

    px, py = par_map[corner]
    try:
        stoner.par[px] = stoner.par[px].val + dx
        stoner.par[py] = stoner.par[py].val + dy
        debug(f"[projection_helpers] Nudged '{corner}' by ({dx:+.4f}, {dy:+.4f})")
    except Exception as e:
        debug(f"[projection_helpers] Nudge failed: {e}")


# ── Output resolution ─────────────────────────────────────────────────────────

def set_output_resolution(width=1920, height=1080):
    """
    Set Window COMP and Out TOP to the given resolution.
    Call this to match your physical projector's native resolution.
    """
    window = _window()
    if window:
        try:
            window.par.winw = width
            window.par.winh = height
            debug(f"[projection_helpers] ✓ Window COMP → {width}×{height}")
        except Exception as e:
            debug(f"[projection_helpers] ⚠ Window resize failed: {e}")

    out = _out()
    if out:
        try:
            out.par.resolutionw = width
            out.par.resolutionh = height
            debug(f"[projection_helpers] ✓ Out TOP → {width}×{height}")
        except Exception as e:
            debug(f"[projection_helpers] ⚠ Out TOP resize failed: {e}")

    render = op(RENDER_OP)
    if render:
        try:
            render.par.resolutionw = width
            render.par.resolutionh = height
        except Exception:
            pass


# ── Zone management ───────────────────────────────────────────────────────────

def assign_zone(zone_name, x, y, w, h):
    """
    Register a named projection zone as a UV rectangle.

    zone_name : string label (e.g. 'dress_front', 'floor', 'shoulder')
    x, y      : top-left corner in 0–1 UV space
    w, h      : width and height in 0–1 UV space

    Example:
        ph.assign_zone('dress_front', 0.25, 0.10, 0.50, 0.75)
    """
    _zones[zone_name] = {"x": x, "y": y, "w": w, "h": h}
    debug(f"[projection_helpers] Zone '{zone_name}' → x={x}, y={y}, w={w}, h={h}")


def get_zone_rect(zone_name):
    """
    Retrieve the UV rect dict for a named zone.
    Returns None if zone does not exist.
    """
    zone = _zones.get(zone_name)
    if zone is None:
        debug(f"[projection_helpers] Zone '{zone_name}' not found.")
    return zone


def list_zones():
    """Print all registered zones to the TextPort."""
    if not _zones:
        debug("[projection_helpers] No zones registered.")
        return
    debug(f"[projection_helpers] Registered zones ({len(_zones)}):")
    for name, rect in _zones.items():
        debug(f"   {name:20s} → x={rect['x']:.3f}  y={rect['y']:.3f}  w={rect['w']:.3f}  h={rect['h']:.3f}")


# ── Test patterns ─────────────────────────────────────────────────────────────

def simulate_test_pattern(pattern="grid"):
    """
    Temporarily override the fluid visual with a calibration test pattern.
    Wires a pre-built TOP into the Stoner input for alignment purposes.

    pattern: 'grid' | 'white' | 'crosshair' | 'restore'

    Example:
        ph.simulate_test_pattern('grid')   # show grid
        ph.simulate_test_pattern('restore') # put fluid visual back
    """
    stoner = _stoner()
    if stoner is None:
        return

    pattern_ops = {
        "white":     "const_white",
        "grid":      "grid_pattern",
        "crosshair": "crosshair_pattern",
    }

    if pattern == "restore":
        out = _out()
        if out and stoner:
            try:
                stoner.inputConnectors[0].connect(out)
                debug("[projection_helpers] ✓ Fluid visual restored to Stoner input.")
            except Exception as e:
                debug(f"[projection_helpers] Restore failed: {e}")
        return

    target_name = pattern_ops.get(pattern)
    if target_name is None:
        debug(f"[projection_helpers] Unknown pattern '{pattern}'. Use: grid, white, crosshair, restore")
        return

    target = op(target_name)
    if target is None:
        debug(f"[projection_helpers] ⚠ Test pattern operator '{target_name}' not found.")
        debug("[projection_helpers]   Add a Constant TOP named 'const_white' (value 1,1,1)")
        debug("[projection_helpers]   and a Grid TOP named 'grid_pattern' to your network.")
        return

    try:
        stoner.inputConnectors[0].connect(target)
        debug(f"[projection_helpers] ✓ Test pattern '{pattern}' connected to Stoner.")
    except Exception as e:
        debug(f"[projection_helpers] Connection failed: {e}")


# ── Diagnostics ───────────────────────────────────────────────────────────────

def print_calibration_state():
    """
    Print current Stoner COMP corner-pin positions to the TextPort.
    Useful for documenting the calibration for a specific venue.
    """
    stoner = _stoner()
    if stoner is None:
        return

    debug("── Stoner Calibration State ──────────────────")
    for label, px, py in [
        ("Top-Left",     "ulx", "uly"),
        ("Top-Right",    "urx", "ury"),
        ("Bottom-Right", "lrx", "lry"),
        ("Bottom-Left",  "llx", "lly"),
    ]:
        try:
            x = stoner.par[px].val
            y = stoner.par[py].val
            debug(f"  {label:14s} : x={x:+.4f}  y={y:+.4f}")
        except Exception:
            debug(f"  {label:14s} : (unreadable)")

    window = _window()
    if window:
        try:
            debug(f"  Resolution   : {int(window.par.winw.val)}×{int(window.par.winh.val)}")
            debug(f"  Display      : {window.par.monitor.val}")
        except Exception:
            pass

    debug(f"  Calib file   : {_calib_path()}")
    debug("──────────────────────────────────────────────")
    list_zones()
