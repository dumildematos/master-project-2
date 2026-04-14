"""
osc_callbacks.py — Sentio TouchDesigner
=========================================
Attach to the DAT Execute DAT connected to oscin1.

Configure the OSC In DAT:
    Network Address : 127.0.0.1
    Port            : 7000
    Address Pattern : /sentio/*
    Active          : On

This is the single entry point for all EEG data entering TouchDesigner.
It writes raw values into the 'sentio_params' Table DAT; downstream
scripts (signal_processor, emotion_mapper, etc.) read from that table.
"""

import json

# ── Operator reference ────────────────────────────────────────────────────────
PARAMS_TABLE = "sentio_params"

# EEG band addresses that carry normalised float values (0.0 – 1.0)
FLOAT_ADDRESSES = {
    "/sentio/alpha",
    "/sentio/beta",
    "/sentio/theta",
    "/sentio/gamma",
    "/sentio/delta",
    "/sentio/confidence",
    "/sentio/complexity",
    "/sentio/signal_quality",
}

# Running message counter per address (for traffic monitoring)
_msg_counts = {}


# ── Helpers ───────────────────────────────────────────────────────────────────

def _table():
    """Return the sentio_params Table DAT, or None if not found."""
    t = op(PARAMS_TABLE)
    if t is None:
        debug(f"[osc_callbacks] WARNING: '{PARAMS_TABLE}' Table DAT not found.")
    return t


def _clamp01(value):
    """Clamp a float to [0.0, 1.0] and return it."""
    try:
        return max(0.0, min(1.0, float(value)))
    except (TypeError, ValueError):
        return 0.0


def _write(table, key, value):
    """
    Write a value to the Table DAT row matching key (column 0).
    Appends a new row if the key does not exist yet.
    """
    cell = table.findCell(str(key), col=0)
    if cell is not None:
        table[cell.row, 1] = value
    else:
        table.appendRow([key, value])


def _increment_counter(address):
    _msg_counts[address] = _msg_counts.get(address, 0) + 1


# ── Band writers ──────────────────────────────────────────────────────────────

def _write_band(table, band_name, raw_value):
    """
    Validate and write a single EEG band power value.
    band_name: 'alpha' | 'beta' | 'theta' | 'gamma' | 'delta'
    raw_value: expected float 0.0 – 1.0
    """
    value = _clamp01(raw_value)
    _write(table, band_name, value)


def _write_scalar(table, key, raw_value):
    """Write a generic scalar float (confidence, complexity, signal_quality)."""
    _write(table, key, _clamp01(raw_value))


def _write_emotion(table, emotion_str):
    """
    Validate and write the emotion label string.
    Falls back to 'neutral' for unknown values.
    """
    valid = ("calm", "focused", "stressed", "relaxed", "excited", "neutral")
    emotion = str(emotion_str).strip().lower()
    if emotion not in valid:
        debug(f"[osc_callbacks] Unknown emotion '{emotion}' — defaulting to 'neutral'")
        emotion = "neutral"
    _write(table, "emotion", emotion)


def _write_palette(table, args):
    """
    Serialise a colour palette from OSC args into a JSON string.

    The backend can send the palette as:
      - A single JSON-encoded string arg: '["#2DD4E8","#9B6FDB"]'
      - Multiple string args: "#2DD4E8", "#9B6FDB", ...
    """
    if not args:
        return

    # Case 1: single JSON string
    if len(args) == 1:
        try:
            palette = json.loads(str(args[0]))
            if isinstance(palette, list):
                _write(table, "color_palette", json.dumps(palette))
                return
        except (json.JSONDecodeError, TypeError):
            pass

    # Case 2: multiple individual hex string args
    palette = [str(a) for a in args if str(a).startswith("#")]
    if palette:
        _write(table, "color_palette", json.dumps(palette))


# ── Main OSC callback ─────────────────────────────────────────────────────────

def onReceiveOSC(dat, rowIndex, message, bytes, timeStamp, address, args, peer):
    """
    Called by DAT Execute for every incoming OSC message.

    Dispatch table:
        /sentio/alpha          → float band value
        /sentio/beta           → float band value
        /sentio/theta          → float band value
        /sentio/gamma          → float band value
        /sentio/delta          → float band value
        /sentio/emotion        → string label
        /sentio/confidence     → float 0–1
        /sentio/complexity     → float 0–1
        /sentio/signal_quality → float 0–1
        /sentio/color_palette  → JSON array or multi-arg hex strings
    """
    if not address.startswith("/sentio/"):
        return

    table = _table()
    if table is None:
        return

    _increment_counter(address)
    value = args[0] if args else None

    # ── EEG band floats ───────────────────────────────────────────────────────
    if address in FLOAT_ADDRESSES:
        key = address.split("/")[-1]   # e.g. "alpha", "confidence"
        _write_scalar(table, key, value)
        return

    # ── Emotion string ────────────────────────────────────────────────────────
    if address == "/sentio/emotion":
        _write_emotion(table, value)
        return

    # ── Colour palette array ──────────────────────────────────────────────────
    if address == "/sentio/color_palette":
        _write_palette(table, args)
        return

    # ── Unknown /sentio/* address (future extensibility) ─────────────────────
    debug(f"[osc_callbacks] Unhandled OSC address: {address}")


# ── Other required DAT Execute callbacks (leave empty / pass) ─────────────────

def onReceiveOSCBundle(dat, timeStamp, messages, peer):
    pass


def onSetupParameters(scriptOp):
    pass


# ── Traffic monitoring (call from debug_utils or TextPort) ───────────────────

def get_message_counts():
    """Return a dict of {address: count} for all received messages."""
    return dict(_msg_counts)


def reset_message_counts():
    """Reset all traffic counters to zero."""
    _msg_counts.clear()
