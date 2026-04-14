"""
constants.py — Sentio TouchDesigner
====================================
Shared constants used across all Sentio TD scripts.
Load this as a Module-on-Demand Script DAT named `sentio_const`
and access via: import sentio_const  OR  op('sentio_const').module.VALUE

Do NOT place in an Execute DAT — this is a passive data module only.
"""

# ── OSC ───────────────────────────────────────────────────────────────────────
OSC_PORT           = 7000
OSC_ADDRESS_PREFIX = "/sentio"

# All expected OSC address paths
OSC_ALPHA          = "/sentio/alpha"
OSC_BETA           = "/sentio/beta"
OSC_THETA          = "/sentio/theta"
OSC_GAMMA          = "/sentio/gamma"
OSC_DELTA          = "/sentio/delta"
OSC_EMOTION        = "/sentio/emotion"
OSC_CONFIDENCE     = "/sentio/confidence"
OSC_COMPLEXITY     = "/sentio/complexity"
OSC_COLOR_PALETTE  = "/sentio/color_palette"
OSC_SIGNAL_QUALITY = "/sentio/signal_quality"

EEG_BANDS = ("alpha", "beta", "theta", "gamma", "delta")

# ── Operator names (match your TD network exactly) ────────────────────────────
OP_PARAMS_TABLE    = "sentio_params"
OP_OSC_IN          = "oscin1"
OP_FILTER_CHOP     = "filter_chop"
OP_NULL_CHOP       = "null_chop"
OP_NOISE_TOP       = "noise1"
OP_REMAP_TOP       = "remap1"
OP_BLUR_TOP        = "blur1"
OP_COMPOSITE_TOP   = "composite1"
OP_FEEDBACK_TOP    = "feedback1"
OP_LEVEL_TOP       = "level1"
OP_HSV_TOP         = "hsvAdjust1"
OP_BLOOM_TOP       = "bloom1"
OP_OUT_TOP         = "out1"
OP_PARTICLES       = "particles1"
OP_GEO_COMP        = "geo1"
OP_RENDER_TOP      = "render1"
OP_STONER          = "stoner1"
OP_WINDOW          = "window1"
OP_CONST_HUE       = "constant_hue"
OP_CONST_FLOW      = "constant_flow"
OP_CONST_DIST      = "constant_dist"

# ── sentio_params Table DAT row keys ─────────────────────────────────────────
ROW_ALPHA           = "alpha"
ROW_BETA            = "beta"
ROW_THETA           = "theta"
ROW_GAMMA           = "gamma"
ROW_DELTA           = "delta"
ROW_EMOTION         = "emotion"
ROW_CONFIDENCE      = "confidence"
ROW_COMPLEXITY      = "complexity"
ROW_COLOR_PALETTE   = "color_palette"
ROW_SIGNAL_QUALITY  = "signal_quality"
ROW_MODE            = "mode"

# Preset rows (written by emotion_mapper, read by param_handler)
ROW_PRESET_HUE       = "preset_hue_shift"
ROW_PRESET_SAT       = "preset_saturation"
ROW_PRESET_NOISE_P   = "preset_noise_period"
ROW_PRESET_BLUR      = "preset_blur_radius"
ROW_PRESET_FEEDBACK  = "preset_feedback_strength"
ROW_PRESET_BLOOM     = "preset_bloom_threshold"
ROW_PRESET_PARTICLES = "preset_particle_rate"
ROW_PRESET_FLOW      = "preset_flow_speed"
ROW_PRESET_DIST      = "preset_distortion"

ALL_PARAM_ROWS = (
    ROW_ALPHA, ROW_BETA, ROW_THETA, ROW_GAMMA, ROW_DELTA,
    ROW_EMOTION, ROW_CONFIDENCE, ROW_COMPLEXITY,
    ROW_COLOR_PALETTE, ROW_SIGNAL_QUALITY, ROW_MODE,
    ROW_PRESET_HUE, ROW_PRESET_SAT, ROW_PRESET_NOISE_P,
    ROW_PRESET_BLUR, ROW_PRESET_FEEDBACK, ROW_PRESET_BLOOM,
    ROW_PRESET_PARTICLES, ROW_PRESET_FLOW, ROW_PRESET_DIST,
)

# ── Default values (safe state before first OSC packet) ───────────────────────
DEFAULTS = {
    ROW_ALPHA:           0.50,
    ROW_BETA:            0.20,
    ROW_THETA:           0.20,
    ROW_GAMMA:           0.05,
    ROW_DELTA:           0.05,
    ROW_EMOTION:         "calm",
    ROW_CONFIDENCE:      1.00,
    ROW_COMPLEXITY:      0.20,
    ROW_COLOR_PALETTE:   "[]",
    ROW_SIGNAL_QUALITY:  1.00,
    ROW_MODE:            "live",
    ROW_PRESET_HUE:      200.0,
    ROW_PRESET_SAT:      0.70,
    ROW_PRESET_NOISE_P:  6.0,
    ROW_PRESET_BLUR:     8.0,
    ROW_PRESET_FEEDBACK: 0.82,
    ROW_PRESET_BLOOM:    0.65,
    ROW_PRESET_PARTICLES:0.30,
    ROW_PRESET_FLOW:     0.18,
    ROW_PRESET_DIST:     0.12,
}

# ── Emotion names ─────────────────────────────────────────────────────────────
VALID_EMOTIONS = ("calm", "focused", "stressed", "relaxed", "excited", "neutral")

# Emotion → base hue (degrees, 0–360)
EMOTION_HUE = {
    "calm":     200,
    "focused":   42,
    "stressed":   5,
    "relaxed":  175,
    "excited":  285,
    "neutral":  220,
}

# ── Signal quality thresholds ─────────────────────────────────────────────────
QUALITY_GOOD        = 0.70   # >= this: normal operation
QUALITY_DEGRADED    = 0.40   # >= this and < GOOD: hold last values
QUALITY_CRITICAL    = 0.15   # >= this and < DEGRADED: enter fallback mode
# below CRITICAL: disconnected state

# ── Visual parameter ranges ───────────────────────────────────────────────────
NOISE_PERIOD_MIN    = 0.5
NOISE_PERIOD_MAX    = 12.0
BLUR_RADIUS_MIN     = 1.0
BLUR_RADIUS_MAX     = 20.0
FEEDBACK_MIN        = 0.60
FEEDBACK_MAX        = 0.98
BLOOM_THRESH_MIN    = 0.20
BLOOM_THRESH_MAX    = 0.90
PARTICLE_RATE_MIN   = 10.0   # particles / second
PARTICLE_RATE_MAX   = 900.0

# ── Smoothing ─────────────────────────────────────────────────────────────────
SMOOTH_FAST     = 0.15   # responsive — used for beat-reactive params
SMOOTH_MEDIUM   = 0.06   # balanced — used for most visual params
SMOOTH_SLOW     = 0.025  # cinematic — used for colour and atmosphere

# Emotion transition: blend duration in seconds
EMOTION_BLEND_SECONDS = 2.5

# ── Fallback visual preset (shown during signal dropout) ─────────────────────
FALLBACK_PRESET = {
    ROW_PRESET_HUE:       220.0,
    ROW_PRESET_SAT:       0.30,
    ROW_PRESET_NOISE_P:   8.0,
    ROW_PRESET_BLUR:      12.0,
    ROW_PRESET_FEEDBACK:  0.92,
    ROW_PRESET_BLOOM:     0.80,
    ROW_PRESET_PARTICLES: 0.05,
    ROW_PRESET_FLOW:      0.08,
    ROW_PRESET_DIST:      0.04,
}

# ── Projection output ─────────────────────────────────────────────────────────
OUTPUT_WIDTH    = 1920
OUTPUT_HEIGHT   = 1080
OUTPUT_FPS      = 60
