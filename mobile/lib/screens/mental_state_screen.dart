// =============================================================================
//  MentalStateScreen
//  Appears when the user taps "Current State" on the Dashboard.
//  Shows 5 EEG-detected emotional states; auto-selects the live emotion.
//
//  Packages: google_fonts, provider
//  All icons are drawn with CustomPainter to match the reference design.
// =============================================================================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/sentio_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kBg     = Color(0xFF02080D);
const _kCard   = Color(0xFF101820);
const _kCyan   = Color(0xFF00D9FF);
const _kGreen  = Color(0xFF00C48C);
const _kPurple = Color(0xFF782CFF);
const _kRed    = Color(0xFFFF4D4D);
const _kAmber  = Color(0xFFFFC107);
const _kMuted  = Color(0xFF9AA6B2);

TextStyle _pp({
  double size = 14, FontWeight weight = FontWeight.normal,
  Color color = Colors.white, double? spacing,
}) => GoogleFonts.poppins(
  fontSize: size, fontWeight: weight,
  color: color, letterSpacing: spacing,
);

// ── State definitions ─────────────────────────────────────────────────────────
class _StateData {
  final String key, label, description;
  final Color  color;
  final Widget Function(Color) iconBuilder;

  const _StateData({
    required this.key,
    required this.label,
    required this.description,
    required this.color,
    required this.iconBuilder,
  });
}

List<_StateData> _states() => [
  _StateData(
    key: 'calm', label: 'Calm',
    description: 'Relaxed and at ease',
    color: _kCyan,
    iconBuilder: (c) => CustomPaint(painter: _WavesPainter(c)),
  ),
  _StateData(
    key: 'focused', label: 'Focused',
    description: 'Deep concentration',
    color: _kGreen,
    iconBuilder: (c) => CustomPaint(painter: _CrosshairPainter(c)),
  ),
  _StateData(
    key: 'relaxed', label: 'Relaxed',
    description: 'Light and peaceful',
    color: _kPurple,
    iconBuilder: (c) => CustomPaint(painter: _LotusPainter(c)),
  ),
  _StateData(
    key: 'stressed', label: 'Stressed',
    description: 'High mental tension',
    color: _kRed,
    iconBuilder: (c) => CustomPaint(painter: _AtomPainter(c)),
  ),
  _StateData(
    key: 'excited', label: 'Excited',
    description: 'High energy',
    color: _kAmber,
    iconBuilder: (c) => CustomPaint(painter: _LightningPainter(c)),
  ),
];

// =============================================================================
//  Screen
// =============================================================================
class MentalStateScreen extends StatelessWidget {
  const MentalStateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    final emotion = context
        .watch<SentioProvider>()
        .data
        .emotion
        .toLowerCase();

    final states = _states();

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────────
          _Header(onBack: () => Navigator.pop(context)),

          // ── Card list ────────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              itemCount: states.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, i) => MentalStateCard(
                state:    states[i],
                selected: states[i].key == emotion,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// =============================================================================
//  Header
// =============================================================================
class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(children: [
          // Back button
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF182030)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
            ),
          ),
          // Title
          Expanded(
            child: Text(
              'Mental State',
              textAlign: TextAlign.center,
              style: _pp(size: 18, weight: FontWeight.bold),
            ),
          ),
          // Info button
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF182030)),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: _kMuted, size: 20),
          ),
        ]),
      );
}

// =============================================================================
//  MentalStateCard  (reusable)
// =============================================================================
class MentalStateCard extends StatelessWidget {
  final _StateData state;
  final bool       selected;

  const MentalStateCard({
    super.key,
    required this.state,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final col = state.color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: selected
              ? col.withOpacity(0.45)
              : const Color(0xFF182030),
          width: selected ? 1.4 : 1.0,
        ),
        boxShadow: selected
            ? [BoxShadow(
                color: col.withOpacity(0.14),
                blurRadius: 24, spreadRadius: 2)]
            : const [],
      ),
      child: Row(children: [
        // ── Coloured icon container ─────────────────────────────────
        Container(
          width: 58, height: 58,
          decoration: BoxDecoration(
            color: col.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: col.withOpacity(0.22),
                blurRadius: 16, spreadRadius: 0),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: 34, height: 34,
              child: state.iconBuilder(col),
            ),
          ),
        ),
        const SizedBox(width: 18),

        // ── Label + description ─────────────────────────────────────
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.label,
              style: _pp(
                size: 16,
                weight: FontWeight.w600,
                color: selected ? col : Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              state.description,
              style: _pp(size: 13, color: _kMuted),
            ),
          ],
        )),

        // ── Check indicator ─────────────────────────────────────────
        const SizedBox(width: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: selected
              ? Container(
                  key: const ValueKey(true),
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2979FF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2979FF).withOpacity(0.4),
                        blurRadius: 10, spreadRadius: 1),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 18),
                )
              : const SizedBox(key: ValueKey(false), width: 32, height: 32),
        ),
      ]),
    );
  }
}

// =============================================================================
//  Icon Painters
// =============================================================================

// ── Waves  (Calm) ─────────────────────────────────────────────────────────────
class _WavesPainter extends CustomPainter {
  final Color color;
  const _WavesPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color       = color
      ..style       = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.085
      ..strokeCap   = StrokeCap.round;

    for (int row = 0; row < 3; row++) {
      final baseY = size.height * (0.22 + row * 0.28);
      final path  = Path();
      const steps = 30;
      for (int i = 0; i <= steps; i++) {
        final x  = (i / steps) * size.width;
        final y  = baseY + size.height * 0.09
                   * math.sin(i / steps * math.pi * 2.5 - math.pi / 4);
        if (i == 0) path.moveTo(x, y);
        else         path.lineTo(x, y);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_WavesPainter o) => o.color != color;
}

// ── Crosshair  (Focused) ──────────────────────────────────────────────────────
class _CrosshairPainter extends CustomPainter {
  final Color color;
  const _CrosshairPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color       = color
      ..style       = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap   = StrokeCap.round;

    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.41;

    // Outer circle (4 arcs with small gaps at cardinal points)
    const gapAngle = 0.22; // radians
    const arcSpan  = math.pi / 2 - gapAngle;
    for (int i = 0; i < 4; i++) {
      final start = -math.pi / 2 + i * math.pi / 2 + gapAngle / 2;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start, arcSpan, false, p);
    }

    // Inner small circle
    canvas.drawCircle(c, r * 0.22, p);

    // 4 extending tick lines outside the circle
    const tickFrac = 0.30;
    for (int i = 0; i < 4; i++) {
      final angle = -math.pi / 2 + i * math.pi / 2;
      final p1    = Offset(c.dx + r * 1.05 * math.cos(angle),
                           c.dy + r * 1.05 * math.sin(angle));
      final p2    = Offset(c.dx + r * (1.05 + tickFrac) * math.cos(angle),
                           c.dy + r * (1.05 + tickFrac) * math.sin(angle));
      canvas.drawLine(p1, p2, p);
    }
  }

  @override
  bool shouldRepaint(_CrosshairPainter o) => o.color != color;
}

// ── Lotus  (Relaxed) ─────────────────────────────────────────────────────────
class _LotusPainter extends CustomPainter {
  final Color color;
  const _LotusPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final sw = size.width * 0.075;
    final p  = Paint()
      ..color       = color
      ..style       = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round;

    final w  = size.width;
    final h  = size.height;
    final cx = w / 2;
    final cy = h * 0.62;

    void petal(double bx, double by, double tilt, double pw, double ph) {
      final c  = math.cos(tilt);
      final s  = math.sin(tilt);
      final tx = bx - ph * s;
      final ty = by - ph * c;
      final lc1x = bx - ph * 0.30 * s - pw * c;
      final lc1y = by - ph * 0.30 * c + pw * s;
      final lc2x = tx - pw * 0.50 * c;
      final lc2y = ty + pw * 0.50 * s;
      final rc1x = bx - ph * 0.30 * s + pw * c;
      final rc1y = by - ph * 0.30 * c - pw * s;
      final rc2x = tx + pw * 0.50 * c;
      final rc2y = ty - pw * 0.50 * s;
      canvas.drawPath(
        Path()
          ..moveTo(bx, by)
          ..cubicTo(lc1x, lc1y, lc2x, lc2y, tx, ty)
          ..cubicTo(rc2x, rc2y, rc1x, rc1y, bx, by),
        p,
      );
    }

    petal(cx, cy, 0,      w * 0.150, h * 0.50);
    petal(cx - w * 0.04, cy - h * 0.03, -0.48, w * 0.125, h * 0.40);
    petal(cx + w * 0.04, cy - h * 0.03,  0.48, w * 0.125, h * 0.40);
    petal(cx - w * 0.08, cy - h * 0.01, -0.98, w * 0.095, h * 0.30);
    petal(cx + w * 0.08, cy - h * 0.01,  0.98, w * 0.095, h * 0.30);

    canvas.drawPath(
      Path()
        ..moveTo(cx - w * 0.36, cy + h * 0.06)
        ..cubicTo(
          cx - w * 0.10, cy + h * 0.155,
          cx + w * 0.10, cy + h * 0.155,
          cx + w * 0.36, cy + h * 0.06),
      p..strokeWidth = sw * 0.8,
    );
  }

  @override
  bool shouldRepaint(_LotusPainter o) => o.color != color;
}

// ── Atom / Chaos  (Stressed) ──────────────────────────────────────────────────
class _AtomPainter extends CustomPainter {
  final Color color;
  const _AtomPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color       = color
      ..style       = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.072
      ..strokeCap   = StrokeCap.round;

    final c  = Offset(size.width / 2, size.height / 2);
    final rx = size.width  * 0.46;
    final ry = size.height * 0.20;

    // 3 overlapping ellipses at 0°, 60°, 120°
    for (int i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(i * math.pi / 3);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset.zero,
            width:  rx * 2,
            height: ry * 2),
        p);
      canvas.restore();
    }

    // Centre nucleus dot
    canvas.drawCircle(c, size.width * 0.09,
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_AtomPainter o) => o.color != color;
}

// ── Lightning bolt  (Excited) ─────────────────────────────────────────────────
class _LightningPainter extends CustomPainter {
  final Color color;
  const _LightningPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Classic bold lightning bolt
    final path = Path()
      ..moveTo(w * 0.62, h * 0.04)
      ..lineTo(w * 0.24, h * 0.50)
      ..lineTo(w * 0.50, h * 0.50)
      ..lineTo(w * 0.36, h * 0.96)
      ..lineTo(w * 0.76, h * 0.46)
      ..lineTo(w * 0.50, h * 0.46)
      ..lineTo(w * 0.62, h * 0.04)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LightningPainter o) => o.color != color;
}
