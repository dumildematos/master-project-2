"""
generate_architecture_diagram.py
Creates docs/screenshots/architecture.png — the Sentio system architecture diagram.
Run: python generate_architecture_diagram.py
"""

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import os

OUT = os.path.join(os.path.dirname(__file__), "docs", "screenshots", "architecture.png")
os.makedirs(os.path.dirname(OUT), exist_ok=True)

# ── Theme colours ─────────────────────────────────────────────────────────────
BG        = "#080b14"
BG_CARD   = "#0f1320"
BG_ELEV   = "#141926"
BORDER    = "#1e2640"
CYAN      = "#2dd4de"
PURPLE    = "#9b7fe8"
MAGENTA   = "#c96abf"
AMBER     = "#f0a832"
GREEN     = "#4ade80"
MUTED     = "#6b7a9e"
WHITE     = "#e8ecf5"
RED       = "#e05252"

fig, ax = plt.subplots(figsize=(16, 9))
fig.patch.set_facecolor(BG)
ax.set_facecolor(BG)
ax.set_xlim(0, 16)
ax.set_ylim(0, 9)
ax.axis("off")

# ── Helper: draw a rounded box ────────────────────────────────────────────────
def box(cx, cy, w, h, label, sublabel="", color=CYAN, icon=""):
    x, y = cx - w/2, cy - h/2
    rect = FancyBboxPatch(
        (x, y), w, h,
        boxstyle="round,pad=0.08",
        linewidth=1.5,
        edgecolor=color,
        facecolor=BG_ELEV,
        zorder=3,
    )
    ax.add_patch(rect)
    # glow shadow
    glow = FancyBboxPatch(
        (x - 0.04, y - 0.04), w + 0.08, h + 0.08,
        boxstyle="round,pad=0.12",
        linewidth=0,
        edgecolor="none",
        facecolor=color,
        alpha=0.08,
        zorder=2,
    )
    ax.add_patch(glow)

    top_text = (icon + "  " if icon else "") + label
    ax.text(cx, cy + (0.22 if sublabel else 0), top_text,
            ha="center", va="center",
            fontsize=10, fontweight="bold", color=WHITE,
            fontfamily="monospace", zorder=4)
    if sublabel:
        ax.text(cx, cy - 0.28, sublabel,
                ha="center", va="center",
                fontsize=7.5, color=MUTED,
                fontfamily="monospace", zorder=4)

def arrow(x1, y1, x2, y2, color=MUTED, label="", curved=False):
    style = "arc3,rad=0.3" if curved else "arc3,rad=0"
    ax.annotate(
        "", xy=(x2, y2), xytext=(x1, y1),
        arrowprops=dict(
            arrowstyle="-|>",
            color=color,
            lw=1.4,
            connectionstyle=style,
        ),
        zorder=5,
    )
    if label:
        mx, my = (x1+x2)/2, (y1+y2)/2
        ax.text(mx, my + 0.18, label,
                ha="center", va="bottom",
                fontsize=7, color=color,
                fontfamily="monospace", zorder=6)

def dashed_box(cx, cy, w, h, label, color=BORDER):
    x, y = cx - w/2, cy - h/2
    rect = FancyBboxPatch(
        (x, y), w, h,
        boxstyle="round,pad=0.1",
        linewidth=1,
        linestyle="--",
        edgecolor=color,
        facecolor=BG_CARD,
        zorder=1,
        alpha=0.6,
    )
    ax.add_patch(rect)
    ax.text(cx, y + h + 0.15, label,
            ha="center", va="bottom",
            fontsize=7.5, color=color,
            fontfamily="monospace", zorder=2)

# ── Title ─────────────────────────────────────────────────────────────────────
ax.text(8, 8.6, "SENTIO  —  System Architecture",
        ha="center", va="center",
        fontsize=15, fontweight="bold", color=CYAN,
        fontfamily="monospace", zorder=6)
ax.text(8, 8.25, "EEG-driven wearable LED matrix  ·  Arduino / ESP32 branch",
        ha="center", va="center",
        fontsize=8.5, color=MUTED, fontfamily="monospace", zorder=6)

# ── Input layer ───────────────────────────────────────────────────────────────
dashed_box(2, 6.3, 3.2, 2.4, "INPUT LAYER", color=MUTED)
box(2, 7.2, 2.6, 0.85, "Muse 2 Headband",  "EEG electrodes", CYAN)
box(2, 6.1, 2.6, 0.85, "BrainFlow / LSL",  "Bluetooth → raw EEG", PURPLE)

# ── Backend layer ─────────────────────────────────────────────────────────────
dashed_box(6.5, 6.3, 3.6, 2.4, "BACKEND LAYER", color=MUTED)
box(6.5, 7.2, 3.0, 0.85, "Python Backend",    "FastAPI / uvicorn", CYAN)
box(6.5, 6.1, 3.0, 0.85, "Signal Processing", "Band power + emotion", PURPLE)

# ── Output layer ──────────────────────────────────────────────────────────────
dashed_box(11.5, 6.3, 3.2, 2.4, "OUTPUT LAYER", color=MUTED)
box(11.5, 7.2, 2.6, 0.85, "ESP32",              "WebSocket client", GREEN)
box(11.5, 6.1, 2.6, 0.85, "WS2812B Matrix",     "16×16 LEDs · t-shirt", MAGENTA)

# ── Frontend (secondary) ──────────────────────────────────────────────────────
dashed_box(6.5, 3.2, 3.6, 2.0, "FRONTEND (MONITORING)", color=MUTED)
box(6.5, 3.5, 3.0, 0.85, "React Dashboard",    "WebSocket consumer", AMBER)
box(6.5, 2.5, 3.0, 0.85, "Manual Mode",        "OSC override · POST /osc/manual", AMBER)

# ── Session config (bottom left) ──────────────────────────────────────────────
box(2, 3.5, 2.6, 0.85, "Session Config",     "age · gender · pattern", PURPLE)

# ── Main arrows (horizontal pipeline) ────────────────────────────────────────
# Muse → BrainFlow
arrow(2, 6.77, 2, 6.52, CYAN, "Bluetooth")
# BrainFlow → Backend
arrow(3.3, 6.1, 5.0, 6.1, CYAN, "BrainFlow SDK")
# Backend → Signal Proc
arrow(6.5, 6.77, 6.5, 6.52, PURPLE)
# Signal Proc → ESP32
arrow(8.0, 6.1, 10.2, 7.2, GREEN, "WebSocket /ws/brain-stream")
# ESP32 → LED Matrix
arrow(11.5, 6.77, 11.5, 6.52, MAGENTA, "GPIO · FastLED")

# ── Secondary arrows ──────────────────────────────────────────────────────────
# Backend → Frontend
arrow(6.5, 5.67, 6.5, 3.93, AMBER, "WebSocket (same stream)", curved=False)
# Session config → Backend
arrow(3.3, 3.5, 5.0, 6.5, PURPLE, "POST /api/session/start", curved=True)
# Frontend manual → Backend
arrow(6.5, 2.07, 5.0, 5.67, AMBER, "POST /api/osc/manual", curved=True)

# ── Pattern names on LED Matrix ───────────────────────────────────────────────
patterns = [
    ("Ondas Fluidas",         "calm / relaxed",   CYAN,    12.8, 4.9),
    ("Padrão Geométrico",     "focused",          AMBER,   12.8, 4.35),
    ("Pulsos Rítmicos",       "stressed / excited", RED,   12.8, 3.8),
    ("Estrelas e Partículas", "neutral",          PURPLE,  12.8, 3.25),
]

ax.text(13.5, 5.35, "PATTERNS", ha="center", fontsize=7.5,
        color=MUTED, fontfamily="monospace", fontweight="bold")
for name, emo, col, px, py in patterns:
    ax.text(px, py, f"● {name}", ha="left", va="center",
            fontsize=7.5, color=col, fontfamily="monospace")
    ax.text(px + 0.25, py - 0.25, emo, ha="left", va="center",
            fontsize=6.5, color=MUTED, fontfamily="monospace")

# Arrow from matrix to patterns box
ax.annotate("", xy=(12.6, 4.3), xytext=(12.05, 6.1),
            arrowprops=dict(arrowstyle="-|>", color=MAGENTA, lw=1.1,
                            connectionstyle="arc3,rad=-0.3"), zorder=5)

# ── Legend ────────────────────────────────────────────────────────────────────
legend_items = [
    (CYAN,    "EEG / Input"),
    (PURPLE,  "Processing"),
    (GREEN,   "ESP32 WiFi"),
    (MAGENTA, "LED Output"),
    (AMBER,   "Frontend"),
]
lx, ly = 0.3, 1.9
ax.text(lx, ly + 0.3, "LEGEND", fontsize=7, color=MUTED,
        fontfamily="monospace", fontweight="bold")
for i, (c, l) in enumerate(legend_items):
    ax.add_patch(mpatches.FancyBboxPatch(
        (lx, ly - i*0.38 - 0.15), 0.3, 0.22,
        boxstyle="round,pad=0.03", facecolor=c, edgecolor="none", alpha=0.7, zorder=4))
    ax.text(lx + 0.42, ly - i*0.38 - 0.04, l,
            fontsize=7.5, color=WHITE, fontfamily="monospace", va="center")

# ── Signal quality note ───────────────────────────────────────────────────────
ax.text(8, 1.3,
        "signal_quality (0–100) → LED brightness   ·   heartbeat frames filtered   ·   idle breathing when no EEG",
        ha="center", fontsize=7.5, color=MUTED, fontfamily="monospace",
        style="italic")

# ── Horizontal rule ───────────────────────────────────────────────────────────
ax.plot([0.5, 15.5], [1.7, 1.7], color=BORDER, lw=0.8, zorder=1)
ax.plot([0.5, 15.5], [8.0, 8.0], color=BORDER, lw=0.8, zorder=1)

plt.tight_layout(pad=0.2)
plt.savefig(OUT, dpi=180, bbox_inches="tight", facecolor=BG)
plt.close()
print("Saved -> " + OUT)
