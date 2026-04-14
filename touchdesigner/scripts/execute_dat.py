"""
execute_dat.py — Sentio TouchDesigner
=======================================
Paste this entire file into the MAIN Execute DAT (name it 'execDat').
Enable ONLY: Frame Start = On.

This is the frame-loop orchestrator. It calls each sub-script module
in the correct order every frame, maintaining the data pipeline:

    Frame N:
        1. signal_processor      — smooth raw OSC bands, compute ratios
        2. signal_quality_monitor — track quality, manage fallback mode
        3. emotion_mapper         — tick emotion preset blend transition
        4. color_palette_manager  — tick colour palette blend transition
        5. param_handler          — drive visual TOP/CHOP operators
        6. particle_controller    — drive Particle SOP

Naming contract — each script must be loaded into a Script DAT:
    Script DAT name           Script file
    ─────────────────────────────────────────────────
    mod_signal_processor      signal_processor.py
    mod_signal_quality        signal_quality_monitor.py
    mod_emotion_mapper        emotion_mapper.py
    mod_color_palette         color_palette_manager.py
    mod_param_handler         param_handler.py
    mod_particle              particle_controller.py
    mod_debug                 debug_utils.py         (optional)

Alternatively, if you paste each script directly into separate
Execute DATs, leave only the relevant onFrameStart function
and remove the module reference calls below.
"""

# ── Module references ─────────────────────────────────────────────────────────
# These will be None if the Script DAT doesn't exist yet — non-fatal.

def _mod(name):
    """Return the .module of a Script DAT by name, or None."""
    o = op(name)
    return o.module if o is not None else None


# ── onFrameStart ──────────────────────────────────────────────────────────────

def onFrameStart(frame):
    """
    Main frame loop — called every frame by TouchDesigner.
    Executes the full Sentio processing pipeline in order.
    """

    # 1. Signal processing — smooth bands, compute derived ratios
    sig = _mod("mod_signal_processor")
    if sig:
        sig.onFrameStart(frame)

    # 2. Quality monitor — classify signal state, enter/exit fallback
    qmon = _mod("mod_signal_quality")
    if qmon:
        qmon.onFrameStart(frame)

    # 3. Emotion mapper — advance blend transition between presets
    emap = _mod("mod_emotion_mapper")
    if emap:
        emap.tick_transition(frame)

    # 4. Colour palette manager — advance palette blend
    cpal = _mod("mod_color_palette")
    if cpal:
        cpal.tick_palette_transition(frame)

    # 5. Parameter handler — write visual params to operators
    ph = _mod("mod_param_handler")
    if ph:
        ph.onFrameStart(frame)

    # 6. Particle controller — update Particle SOP
    pc = _mod("mod_particle")
    if pc:
        pc.onFrameStart(frame)

    # 7. Optional: debug watch output (only when watches are registered)
    dbg = _mod("mod_debug")
    if dbg:
        dbg.tick_watches(frame)
        # Uncomment to enable continuous session logging:
        # dbg.auto_log(frame)


# ── Other Execute DAT callbacks ───────────────────────────────────────────────

def onStart():
    """Startup — delegates to startup_init.py (separate Execute DAT)."""
    pass


def onExit():
    pass


def onFrameEnd(frame):
    pass


def onCreate():
    pass
