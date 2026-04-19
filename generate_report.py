"""
generate_report.py
Generates the Sentio critical academic report as a formatted .docx file.
Run: python generate_report.py
Output: docs/sentio_critical_report.docx
"""

from docx import Document
from docx.shared import Pt, RGBColor, Inches, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.style import WD_STYLE_TYPE
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import os

# ── Output path ───────────────────────────────────────────────────────────────
OUT_DIR  = os.path.join(os.path.dirname(__file__), "docs")
OUT_FILE = os.path.join(OUT_DIR, "sentio_critical_report.docx")
os.makedirs(OUT_DIR, exist_ok=True)

# ── Helpers ───────────────────────────────────────────────────────────────────

def set_font(run, name="Times New Roman", size=12, bold=False,
             italic=False, color=None):
    run.font.name   = name
    run.font.size   = Pt(size)
    run.font.bold   = bold
    run.font.italic = italic
    if color:
        run.font.color.rgb = RGBColor(*color)

def add_heading(doc, text, level=1):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(14)
    p.paragraph_format.space_after  = Pt(4)
    p.paragraph_format.keep_with_next = True
    run = p.add_run(text)
    if level == 0:          # Document title
        set_font(run, size=18, bold=True)
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after  = Pt(6)
    elif level == 1:        # Section heading
        set_font(run, size=13, bold=True)
        p.paragraph_format.space_before = Pt(18)
    elif level == 2:        # Sub-heading (bold inline)
        set_font(run, size=12, bold=True)
        p.paragraph_format.space_before = Pt(10)
    return p

def add_body(doc, text, indent=False, space_after=8):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(space_after)
    if indent:
        p.paragraph_format.left_indent = Cm(0.8)
    p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    run = p.add_run(text)
    set_font(run)
    return p

def add_mixed(doc, parts, indent=False, space_after=8):
    """
    parts = list of (text, bold, italic) tuples.
    """
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(space_after)
    p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    if indent:
        p.paragraph_format.left_indent = Cm(0.8)
    for text, bold, italic in parts:
        run = p.add_run(text)
        set_font(run, bold=bold, italic=italic)
    return p

def add_bullet(doc, text, level=0):
    p = doc.add_paragraph(style="List Bullet")
    p.paragraph_format.left_indent  = Cm(0.6 + level * 0.5)
    p.paragraph_format.space_after  = Pt(3)
    run = p.add_run(text)
    set_font(run, size=11)
    return p

def add_separator(doc):
    p = doc.add_paragraph()
    p.paragraph_format.space_after  = Pt(2)
    p.paragraph_format.space_before = Pt(2)
    pPr = p._p.get_or_add_pPr()
    pBdr = OxmlElement('w:pBdr')
    bottom = OxmlElement('w:bottom')
    bottom.set(qn('w:val'), 'single')
    bottom.set(qn('w:sz'), '6')
    bottom.set(qn('w:space'), '1')
    bottom.set(qn('w:color'), 'AAAAAA')
    pBdr.append(bottom)
    pPr.append(pBdr)

def add_ref(doc, text):
    p = doc.add_paragraph()
    p.paragraph_format.left_indent   = Cm(1.0)
    p.paragraph_format.first_line_indent = Cm(-1.0)
    p.paragraph_format.space_after   = Pt(4)
    run = p.add_run(text)
    set_font(run, size=11)
    return p

# ── Document ──────────────────────────────────────────────────────────────────
doc = Document()

# Page margins
for section in doc.sections:
    section.top_margin    = Cm(2.5)
    section.bottom_margin = Cm(2.5)
    section.left_margin   = Cm(3.0)
    section.right_margin  = Cm(2.5)

# ── Cover / Title ─────────────────────────────────────────────────────────────
add_heading(doc,
    "Sentio: A Critical Evaluation of an EEG-Driven Wearable LED System",
    level=0)

p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_after = Pt(2)
r = p.add_run("Critical Academic Report")
set_font(r, size=11, italic=True, color=(100, 100, 100))

p2 = doc.add_paragraph()
p2.alignment = WD_ALIGN_PARAGRAPH.CENTER
p2.paragraph_format.space_after = Pt(20)
r2 = p2.add_run("Sentio Project  ·  WS2812B Arduino Version  ·  2026")
set_font(r2, size=10, color=(130, 130, 130))

add_separator(doc)

# ── 1. Introduction ───────────────────────────────────────────────────────────
add_heading(doc, "1. Introduction")

add_body(doc,
    "Sentio is an emotion-driven wearable interactive system that translates "
    "real-time electroencephalography (EEG) data into generative visual patterns "
    "rendered on a 16×16 WS2812B LED matrix embedded in a t-shirt. A Muse 2 "
    "headband captures brainwave activity; a Python backend classifies five "
    "emotional states — calm, focused, stressed, relaxed, and excited — and streams "
    "results wirelessly via WebSocket to an ESP32 microcontroller, which drives "
    "256 individually addressable LEDs through four distinct visual patterns: "
    "Ondas Fluidas, Padrão Geométrico, Pulsos Rítmicos, and Estrelas e Partículas. "
    "This report critically evaluates Sentio's effectiveness as an interactive "
    "system, examining usability, interaction design principles, and system-level "
    "thinking to assess how successfully it bridges complex neurological data and "
    "a meaningful wearable experience.")

# ── 2. Usability and Interaction Analysis ─────────────────────────────────────
add_heading(doc, "2. Usability and Interaction Analysis")

add_mixed(doc, [
    ("Effectiveness.  ", True, False),
    ("Sentio achieves its primary goal — transforming EEG input into visible "
     "wearable output — through a clearly defined five-stage pipeline: session "
     "configuration, device connection, calibration, real-time monitoring, and LED "
     "pattern output. This sequential structure supports task completion by "
     "eliminating ambiguity about system state at each stage. However, effectiveness "
     "is contingent on hardware reliability: Bluetooth connectivity between the Muse "
     "headband and the processing machine constitutes a single point of failure "
     "capable of preventing task completion entirely, a structural vulnerability that "
     "the interface does not adequately communicate to users.", False, False),
])

add_mixed(doc, [
    ("Efficiency.  ", True, False),
    ("The onboarding flow (configuration → calibration → monitoring) reduces "
     "cognitive overhead by guiding users through each stage, aligning with "
     "Nielsen's heuristic of ", False, False),
    ("recognition over recall", False, True),
    (" (Nielsen, 1994). Calibration completes automatically, requiring no active "
     "user input — a deliberate affordance constraint that minimises error "
     "opportunity. However, efficiency is undermined by the calibration stage's "
     "opacity: the animated progress bar runs independently of actual backend "
     "processing, meaning users cannot distinguish genuine device communication "
     "from a cosmetic animation. This violates Nielsen's ", False, False),
    ("visibility of system status", False, True),
    (" heuristic and erodes trust, particularly for technically literate users.",
     False, False),
])

add_mixed(doc, [
    ("Satisfaction.  ", True, False),
    ("The wearable form factor — a chest-mounted LED matrix reacting to the "
     "wearer's emotional state — creates a compelling experiential proposition. "
     "The four patterns are perceptually differentiated by hue, morphology, and "
     "animation speed, enabling even casual observers to detect emotional "
     "transitions. This satisfies the criterion of perceptual distinctiveness. "
     "A notable weakness, however, is the absence of secondary feedback channels "
     "(haptic or auditory), and the wearer cannot observe their own chest panel "
     "— creating an inherent observer-wearer asymmetry that limits personal "
     "experiential depth.", False, False),
])

add_mixed(doc, [
    ("Interaction Principles.  ", True, False),
    ("The real-time WebSocket stream, updated at approximately 100–200 ms "
     "intervals, provides continuous feedback aligned with Norman's principle of "
     "", False, False),
    ("immediate and continuous feedback", False, True),
    (" (Norman, 2013). The ", False, False),
    ("signal_quality", False, False),
    (" value (0–100 scale) directly modulates LED brightness, coupling input "
     "confidence to output intensity: low-confidence readings produce dim output, "
     "communicating system uncertainty without explicit error messaging. The idle "
     "breathing animation when no EEG data is present satisfies the ", False, False),
    ("visibility of system status", False, True),
    (" heuristic, preventing misinterpretation of a static display as system failure. "
     "However, pattern transitions are instantaneous on emotion change. The absence "
     "of crossfade or morphing between states violates continuity principles and "
     "produces jarring visual discontinuities that undermine the organic emotional "
     "narrative the system intends to convey.", False, False),
])

# ── 3. System Thinking Perspective ────────────────────────────────────────────
add_heading(doc, "3. System Thinking Perspective")

add_mixed(doc, [
    ("Activity Theory.  ", True, False),
    ("Analysed through Activity Theory (Engeström, 1987), Sentio situates the "
     "wearer as both ", False, False),
    ("subject", False, True),
    (" and primary data source, employing the EEG-to-LED pipeline as ", False, False),
    ("tool", False, True),
    (" to externalise emotional state as ", False, False),
    ("object", False, True),
    (". This framing reveals a fundamental tension: the output medium (a chest "
     "panel) is most visible to external observers, not the wearer themselves. "
     "This inversion of the subject-object relationship is unacknowledged in the "
     "interface design, creating an experiential mismatch that limits personal "
     "agency and self-reflection.", False, False),
])

add_mixed(doc, [
    ("Cognitive Ergonomics.  ", True, False),
    ("From a cognitive ergonomics perspective (Wickens et al., 2004), Sentio "
     "effectively minimises operator mental workload during the monitoring phase — "
     "no active control is required once streaming begins. However, the "
     "configuration stage introduces unnecessary cognitive load by requiring "
     "mandatory demographic inputs (age, gender) without providing sensible "
     "defaults, violating the principle of minimising memory burden and disrupting "
     "flow in exhibition contexts requiring rapid deployment.", False, False),
])

add_mixed(doc, [
    ("Distributed Cognition.  ", True, False),
    ("Hutchins' (1995) framework of distributed cognition provides the strongest "
     "theoretical justification for Sentio's value: the system externalises an "
     "invisible internal state — emotion — into a shared, perceptible artefact. "
     "However, the five-emotion discrete classification model imposes a reductive "
     "taxonomy onto a continuous neurological spectrum. Misclassification — a "
     "stressed signal rendered as focused — breaks the perceived authenticity "
     "central to the system's meaning, and the rule-based classifier offers no "
     "mechanism for individual calibration or adaptive learning.", False, False),
])

add_mixed(doc, [
    ("System Failure Propagation.  ", True, False),
    ("Bluetooth dropout causes EEG loss → the backend emits only heartbeat frames "
     "→ the ESP32 falls back to an idle pattern → observers perceive the garment "
     "as inactive. This cascade is handled gracefully in code but is experienced "
     "externally as the system 'switching off', with no causal indication visible "
     "to observers or the wearer.", False, False),
])

# ── 4. Connection to User Research and Heuristics ─────────────────────────────
add_heading(doc, "4. Connection to User Research and Heuristics")

add_body(doc,
    "Sentio targets an exhibition or performance context, implying novice users "
    "with no EEG literacy. The automated calibration and guided sequential flow "
    "align with Nielsen's error prevention heuristic by removing technical "
    "complexity from user control. The emotion-to-pattern mapping applies "
    "established colour-emotion associations — red/pulse for stress, cyan/wave "
    "for calm (Kaya & Epps, 2004) — reinforcing intuitive readability without "
    "prior instruction.")

add_body(doc,
    "The real-time monitoring interface displays EEG band powers (alpha, beta, "
    "theta, gamma, delta), signal quality, and a detected emotion label with "
    "confidence score. This design decision supports Nielsen's heuristic of "
    "visibility of system status by externalising all pipeline data for the "
    "operator. However, this transparency creates a secondary usability concern: "
    "presenting raw band power values to novice users in an exhibition context "
    "risks cognitive overload through information irrelevant to the wearer's "
    "immediate goal of experiencing the LED output. Progressive disclosure — "
    "hiding technical metrics unless explicitly requested — would better serve "
    "this user profile.")

add_body(doc,
    "The manual override mode, which permits direct OSC parameter injection "
    "without EEG data, demonstrates awareness of operator needs in rehearsal or "
    "fault scenarios. This supports the heuristic of user control and freedom "
    "(Nielsen, 1994) by providing an escape route when the primary input channel "
    "fails. However, the mode is accessible only through the monitoring interface, "
    "requiring a prior successful session start — a constraint that limits its "
    "utility as a fallback during hardware failure.")

# ── 5. Conclusion ─────────────────────────────────────────────────────────────
add_heading(doc, "5. Conclusion")

add_body(doc,
    "Sentio demonstrates technical and experiential feasibility in translating "
    "EEG data to a wearable LED display. Its sequential interaction flow, "
    "signal-quality-driven brightness, and perceptually distinct patterns "
    "constitute a coherent interactive system with clear exhibition value. "
    "Critical weaknesses — calibration feedback opacity, the wearer-as-non-observer "
    "paradox, discrete emotion classification, and instantaneous pattern transitions "
    "— reduce experiential authenticity and limit usability under real-world "
    "deployment conditions.")

add_body(doc,
    "Future iterations should prioritise: (1) pattern morphing interpolation to "
    "smooth emotional transitions; (2) a secondary display or spatial audio "
    "feedback channel oriented towards the wearer; (3) replacement of the discrete "
    "five-emotion taxonomy with a continuous valence-arousal dimensional model; "
    "and (4) a user-adaptive machine-learning classifier to address individual EEG "
    "variability. These developments would move Sentio from a technically "
    "accomplished demonstrator towards a genuinely personalised and robust "
    "human-machine emotional communication system.")

add_separator(doc)

# ── Word count note ───────────────────────────────────────────────────────────
p = doc.add_paragraph()
p.paragraph_format.space_after = Pt(16)
r = p.add_run("Word count: approximately 870 words (excluding references).")
set_font(r, size=10, italic=True, color=(130, 130, 130))
p.alignment = WD_ALIGN_PARAGRAPH.RIGHT

# ── References ────────────────────────────────────────────────────────────────
add_heading(doc, "References")

refs = [
    "Engeström, Y. (1987). Learning by Expanding: An Activity-Theoretical Approach "
    "to Developmental Research. Orienta-Konsultit.",

    "Hutchins, E. (1995). Cognition in the Wild. MIT Press.",

    "Kaya, N., & Epps, H. H. (2004). Relationship between colour and emotion: "
    "A study of college students. College Student Journal, 38(3), 396–405.",

    "Nielsen, J. (1994). Usability Engineering. Academic Press.",

    "Norman, D. A. (2013). The Design of Everyday Things (Revised ed.). Basic Books.",

    "Wickens, C. D., Lee, J. D., Liu, Y., & Gordon-Becker, S. (2004). "
    "An Introduction to Human Factors Engineering (2nd ed.). Pearson Prentice Hall.",
]

for ref in refs:
    add_ref(doc, ref)

# ── Save ──────────────────────────────────────────────────────────────────────
doc.save(OUT_FILE)
print("Saved -> " + OUT_FILE)
