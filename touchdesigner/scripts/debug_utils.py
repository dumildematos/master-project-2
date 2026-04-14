"""
debug_utils.py — Sentio TouchDesigner
=======================================
Runtime debugging and diagnostics toolkit.
NOT called automatically — invoke from the TouchDesigner TextPort
or bind to keyboard shortcuts during development.

Quick TextPort usage:
    import debug_utils as d
    d.snapshot()                      # print all sentio_params rows
    d.chop_channels('filter_chop')    # print CHOP channel values
    d.validate_ranges()               # check for out-of-range values
    d.osc_traffic()                   # show OSC message counts
    d.emotion_presets()               # pretty-print all presets
    d.watch('noise1', ['period','amp'], every=30)  # live param log
    d.simulate_osc('/sentio/alpha', 0.8)           # inject fake OSC value
    d.export_session_log()            # write CSV to project folder
    d.performance_report()            # FPS, cook time, operator count
"""

import json
import os
import csv
from collections import deque

# ── Session log state ─────────────────────────────────────────────────────────
_session_log = []       # list of dicts, one per logged sample
_LOG_INTERVAL = 60      # frames between automatic session log samples
_last_log_frame = 0

# ── Watch state ───────────────────────────────────────────────────────────────
_watches = []   # list of (op_name, par_names, every_n_frames)


# ── Helpers ───────────────────────────────────────────────────────────────────

def _table():
    return op("sentio_params")


def _read(table, key, default=None):
    if table is None:
        return default
    cell = table.findCell(str(key), col=0)
    if cell is None:
        return default
    try:
        return float(table[cell.row, 1])
    except (ValueError, TypeError):
        return str(table[cell.row, 1])


def _sep(char="─", n=60):
    debug(char * n)


def _header(title):
    _sep()
    debug(f"  {title}")
    _sep()


# ── Snapshot ──────────────────────────────────────────────────────────────────

def snapshot():
    """
    Print all rows in sentio_params to the TextPort.
    Groups rows by category for readability.
    """
    table = _table()
    if table is None:
        debug("[debug_utils] ✗ sentio_params not found.")
        return

    _header("sentio_params — Full Snapshot")

    categories = {
        "EEG Bands":   ["alpha", "beta", "theta", "gamma", "delta"],
        "Metadata":    ["emotion", "confidence", "complexity", "signal_quality"],
        "State":       ["mode", "signal_state", "quality_mean", "quality_min"],
        "Processed":   ["proc_flow", "proc_distortion", "proc_engagement",
                        "proc_relaxation", "proc_cognitive", "proc_arousal", "proc_theta_alpha"],
        "Preset":      [r for r in [str(table[i, 0]) for i in range(table.numRows)]
                        if r.startswith("preset_")],
        "Other":       [],
    }

    # Collect keys already categorised
    known = set()
    for keys in categories.values():
        known.update(keys)

    # Anything else goes in Other
    for i in range(table.numRows):
        key = str(table[i, 0])
        if key not in known:
            categories["Other"].append(key)

    for category, keys in categories.items():
        if not keys:
            continue
        debug(f"\n  ── {category}")
        for key in keys:
            cell = table.findCell(key, col=0)
            if cell is None:
                continue
            val_raw = str(table[cell.row, 1])
            # Format floats nicely
            try:
                val = f"{float(val_raw):.4f}"
            except ValueError:
                val = val_raw
            debug(f"    {key:<32s} {val}")

    _sep()


def chop_channels(chop_name):
    """
    Print all channel names and current values from a named CHOP.

    Example: debug_utils.chop_channels('filter_chop')
    """
    chop = op(chop_name)
    if chop is None:
        debug(f"[debug_utils] ✗ CHOP '{chop_name}' not found.")
        return

    _header(f"CHOP: {chop_name}  ({chop.numChans} channels)")
    for i in range(chop.numChans):
        ch = chop[i]
        debug(f"    {ch.name:<24s} {ch.eval():>10.5f}")
    _sep()


# ── Range validation ──────────────────────────────────────────────────────────

EXPECTED_RANGES = {
    "alpha":            (0.0, 1.0),
    "beta":             (0.0, 1.0),
    "theta":            (0.0, 1.0),
    "gamma":            (0.0, 1.0),
    "delta":            (0.0, 1.0),
    "confidence":       (0.0, 1.0),
    "complexity":       (0.0, 1.0),
    "signal_quality":   (0.0, 1.0),
    "preset_hue_shift": (0.0, 360.0),
    "preset_saturation":(0.0, 1.5),
    "preset_noise_period": (0.3, 15.0),
    "preset_blur_radius":  (0.0, 25.0),
    "preset_feedback_strength": (0.0, 1.0),
    "preset_bloom_threshold":   (0.0, 1.0),
    "preset_particle_rate":     (0.0, 1.0),
    "preset_flow_speed":        (0.0, 1.0),
    "preset_distortion":        (0.0, 1.0),
}


def validate_ranges():
    """
    Check all numeric sentio_params values against expected ranges.
    Prints a warning for any value outside its valid range.
    """
    table = _table()
    if table is None:
        debug("[debug_utils] ✗ sentio_params not found.")
        return

    _header("Range Validation")
    issues = 0

    for key, (lo, hi) in EXPECTED_RANGES.items():
        cell = table.findCell(key, col=0)
        if cell is None:
            debug(f"  MISSING   {key}")
            issues += 1
            continue
        try:
            val = float(table[cell.row, 1])
        except (ValueError, TypeError):
            continue

        if val < lo or val > hi:
            debug(f"  OUT OF RANGE  {key:<30s} = {val:.4f}  (expected {lo}–{hi})")
            issues += 1
        else:
            debug(f"  OK            {key:<30s} = {val:.4f}")

    _sep()
    if issues == 0:
        debug("  ✓ All values within expected ranges.")
    else:
        debug(f"  ⚠ {issues} issue(s) found.")
    _sep()


# ── OSC traffic ───────────────────────────────────────────────────────────────

def osc_traffic():
    """
    Print OSC message counts per address from osc_callbacks.py.
    Shows total messages received since last reset.
    """
    try:
        counts = op("datExec").module.get_message_counts()
    except Exception:
        # Try direct import approach
        try:
            import osc_callbacks
            counts = osc_callbacks.get_message_counts()
        except Exception as e:
            debug(f"[debug_utils] ✗ Could not read OSC counts: {e}")
            debug("[debug_utils]   Ensure osc_callbacks.py is loaded in the DAT Execute.")
            return

    _header("OSC Traffic Report")
    if not counts:
        debug("  No OSC messages received yet.")
    else:
        total = sum(counts.values())
        for addr, count in sorted(counts.items(), key=lambda x: -x[1]):
            bar = "█" * min(40, count // max(1, total // 40))
            debug(f"  {addr:<35s} {count:>6d}  {bar}")
        debug(f"\n  Total messages: {total}")
    _sep()


def reset_osc_traffic():
    """Reset all OSC message counters."""
    try:
        op("datExec").module.reset_message_counts()
        debug("[debug_utils] OSC traffic counters reset.")
    except Exception as e:
        debug(f"[debug_utils] ✗ Reset failed: {e}")


# ── Emotion preset dump ───────────────────────────────────────────────────────

def emotion_presets():
    """
    Pretty-print the full emotion preset library from emotion_mapper.
    """
    try:
        presets = op("emotion_mapper_dat").module.get_all_presets()
    except Exception:
        # Fallback: import directly (works when script is loaded as a module)
        try:
            import emotion_mapper
            presets = emotion_mapper.get_all_presets()
        except Exception as e:
            debug(f"[debug_utils] ✗ Could not access emotion_mapper: {e}")
            return

    _header("Emotion Preset Library")
    for emotion, preset in presets.items():
        debug(f"\n  ── {emotion.upper()}")
        for key, val in preset.items():
            debug(f"    {key:<28s} {val}")
    _sep()


# ── Watch ─────────────────────────────────────────────────────────────────────

def watch(op_name, par_names, every=60):
    """
    Register an operator parameter to be printed every N frames.
    Call tick_watches(frame) from the Execute DAT to activate.

    Example:
        d.watch('noise1', ['period', 'amp'], every=30)
    """
    _watches.append({"op": op_name, "pars": par_names, "every": every, "last": 0})
    debug(f"[debug_utils] Watching {op_name}.{par_names} every {every} frames.")


def clear_watches():
    """Remove all registered watches."""
    _watches.clear()
    debug("[debug_utils] All watches cleared.")


def tick_watches(frame):
    """
    Call this from the Execute DAT's onFrameStart to activate parameter watching.
    """
    for w in _watches:
        if frame - w["last"] >= w["every"]:
            w["last"] = frame
            o = op(w["op"])
            if o is None:
                continue
            vals = []
            for pn in w["pars"]:
                try:
                    vals.append(f"{pn}={getattr(o.par, pn).val:.4f}")
                except Exception:
                    vals.append(f"{pn}=?")
            debug(f"[watch] f={frame}  {w['op']}  {', '.join(vals)}")


# ── Simulate OSC ─────────────────────────────────────────────────────────────

def simulate_osc(address, value):
    """
    Inject a fake OSC value directly into sentio_params.
    Use this to test visual responses without a live EEG backend.

    Examples:
        d.simulate_osc('/sentio/alpha', 0.9)
        d.simulate_osc('/sentio/emotion', 'stressed')
        d.simulate_osc('/sentio/signal_quality', 0.0)   # test fallback mode
    """
    table = _table()
    if table is None:
        debug("[debug_utils] ✗ sentio_params not found.")
        return

    if not address.startswith("/sentio/"):
        debug(f"[debug_utils] ✗ Address must start with '/sentio/' — got: {address}")
        return

    key = address.split("/")[-1]
    cell = table.findCell(key, col=0)

    if cell is not None:
        table[cell.row, 1] = value
    else:
        table.appendRow([key, value])

    debug(f"[debug_utils] Simulated OSC: {address} = {value}")


def simulate_emotion_sequence(emotions=None, interval=5.0):
    """
    Cycle through a list of emotions on a timer (non-blocking — call repeatedly).
    Designed to be used with a Timer CHOP or manual timed calls.

    Default sequence: calm → focused → stressed → relaxed → excited
    interval: seconds between transitions

    Example (call from TextPort every few seconds):
        d.simulate_emotion_sequence()
    """
    if emotions is None:
        emotions = ["calm", "focused", "stressed", "relaxed", "excited"]

    ts = absTime.seconds
    idx = int(ts / interval) % len(emotions)
    emotion = emotions[idx]

    simulate_osc("/sentio/emotion",    emotion)
    simulate_osc("/sentio/confidence", 0.92)
    debug(f"[debug_utils] Simulated emotion: {emotion} (t={ts:.1f}s)")


# ── Session log ───────────────────────────────────────────────────────────────

def _sample_session():
    """Take a snapshot of current band + emotion state."""
    table = _table()
    if table is None:
        return

    def r(k):
        return _read(table, k, 0.0)

    _session_log.append({
        "time_s":       round(absTime.seconds, 2),
        "frame":        absTime.frame,
        "alpha":        r("alpha"),
        "beta":         r("beta"),
        "theta":        r("theta"),
        "gamma":        r("gamma"),
        "delta":        r("delta"),
        "emotion":      _read(table, "emotion", ""),
        "confidence":   r("confidence"),
        "complexity":   r("complexity"),
        "signal_quality": r("signal_quality"),
        "signal_state": _read(table, "signal_state", ""),
        "mode":         _read(table, "mode", ""),
    })


def auto_log(frame):
    """
    Called from Execute DAT every frame — automatically samples at _LOG_INTERVAL.
    Add this call to your execDat.onFrameStart if you want continuous logging.
    """
    global _last_log_frame
    if frame - _last_log_frame >= _LOG_INTERVAL:
        _last_log_frame = frame
        _sample_session()


def export_session_log(filepath=None):
    """
    Write the accumulated session log to a timestamped CSV file.

    Example:
        d.export_session_log()
        d.export_session_log('C:/Sessions/my_session.csv')
    """
    if not _session_log:
        debug("[debug_utils] No session data to export. Run auto_log() or sample manually.")
        return

    if filepath is None:
        ts = int(absTime.seconds)
        try:
            folder = os.path.dirname(project.folder)
        except Exception:
            folder = os.getcwd()
        filepath = os.path.join(folder, f"sentio_session_{ts}.csv")

    try:
        keys = list(_session_log[0].keys())
        with open(filepath, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=keys)
            writer.writeheader()
            writer.writerows(_session_log)
        debug(f"[debug_utils] ✓ Session log exported: {filepath}")
        debug(f"[debug_utils]   {len(_session_log)} samples")
    except OSError as e:
        debug(f"[debug_utils] ✗ Export failed: {e}")


def clear_session_log():
    """Clear all accumulated session log data."""
    _session_log.clear()
    debug("[debug_utils] Session log cleared.")


# ── Performance report ────────────────────────────────────────────────────────

def performance_report():
    """
    Print FPS, cook time, and operator count to the TextPort.
    """
    _header("Performance Report")
    try:
        debug(f"  FPS (actual)   : {perf.gpuMemoryUsed:.1f}" if hasattr(perf, 'gpuMemoryUsed') else "  FPS: (unavailable)")
        debug(f"  Cook time      : {perf.cookTime * 1000:.2f} ms")
        debug(f"  GPU memory     : {perf.gpuMemoryUsed:.1f} MB" if hasattr(perf, 'gpuMemoryUsed') else "")
    except Exception:
        pass

    try:
        debug(f"  Total operators: {len(root.findChildren(type=OP))}")
    except Exception:
        pass

    # Check Noise TOP resolution
    noise = op("noise1")
    if noise:
        try:
            debug(f"  Noise TOP res  : {noise.width}×{noise.height}")
        except Exception:
            pass

    # Check render resolution
    render = op("render1")
    if render:
        try:
            debug(f"  Render TOP res : {render.width}×{render.height}")
        except Exception:
            pass

    _sep()
    debug("  Tip: if FPS < 50, lower intermediate TOP resolutions to 1280×720")
    _sep()


# ── Quick health check ────────────────────────────────────────────────────────

def health_check():
    """
    Run a comprehensive health check and print a summary.
    Covers: OSC connection, signal quality, operator chain, value ranges.
    """
    _header("Sentio Health Check")

    # OSC
    osc = op("oscin1")
    if osc and osc.par.active.val:
        debug(f"  ✓ OSC In       : active on port {int(osc.par.port.val)}")
    else:
        debug("  ✗ OSC In       : not active or missing")

    # Signal quality
    table = _table()
    if table:
        q = _read(table, "signal_quality", 0.0)
        state = _read(table, "signal_state", "?")
        mode  = _read(table, "mode", "?")
        debug(f"  {'✓' if q >= 0.7 else '⚠'} Signal quality : {q:.2f}  ({state})  mode={mode}")
        debug(f"  {'✓' if mode == 'live' else '⚠'} Operation mode : {mode}")

    # Key operators
    key_ops = ["noise1", "feedback1", "hsvAdjust1", "bloom1", "out1", "stoner1", "window1"]
    for op_name in key_ops:
        o = op(op_name)
        debug(f"  {'✓' if o else '✗'} {op_name}")

    _sep()
