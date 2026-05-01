import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'login_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kBg       = Color(0xFF02080D);
const _kBgEnd    = Color(0xFF07131B);
const _kCyan     = Color(0xFF00D9FF);
const _kPurple   = Color(0xFF782CFF);
const _kMagenta  = Color(0xFFDD22FF);
const _kWhite    = Color(0xFFFFFFFF);
const _kGray     = Color(0xFF9AA6B2);
const _kDotInact = Color(0xFF2E3A47);

// ══════════════════════════════════════════════════════════════════════════════
// OnboardingScreen
// ══════════════════════════════════════════════════════════════════════════════
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: _kBg,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBackground(t: _ctrl.value),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: h * 0.042),

                  LogoWidget(t: _ctrl.value),
                  SizedBox(height: h * 0.020),

                  // "SENTIO"
                  Text(
                    'SENTIO',
                    style: GoogleFonts.poppins(
                      color: _kCyan,
                      fontSize: 38,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 10,
                    ),
                  ),
                  SizedBox(height: h * 0.005),

                  // "Wear your mind."
                  Text(
                    'Wear your mind.',
                    style: GoogleFonts.poppins(
                      color: _kWhite,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: h * 0.016),

                  const _Separator(),
                  SizedBox(height: h * 0.016),

                  // Supporting subtitle
                  Text(
                    'Real-time brain feedback\nthrough light.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: _kGray,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 1.6,
                    ),
                  ),
                  SizedBox(height: h * 0.014),

                  // Hero image — takes all available space between text and buttons
                  Expanded(
                    child: HeroImageSection(t: _ctrl.value),
                  ),
                  SizedBox(height: h * 0.020),

                  // Pagination dots
                  const PaginationDots(current: 0, total: 5),
                  SizedBox(height: h * 0.022),

                  // Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        GradientButton(
                          label: 'Get Started',
                          onTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SentioOutlineButton(
                          label: 'Log In',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: h * 0.028),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// AnimatedBackground — dual particle wave streams (cyan left, purple right)
// ══════════════════════════════════════════════════════════════════════════════
class AnimatedBackground extends StatelessWidget {
  final double t;
  const AnimatedBackground({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BgPainter(t),
      child: const SizedBox.expand(),
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);

  // Catmull-Rom spline evaluation
  Offset _catmull(List<Offset> pts, double u) {
    final n   = pts.length - 1;
    final seg = (u * n).clamp(0.0, n - 1e-9);
    final i   = seg.floor();
    final f   = seg - i;
    final p0  = pts[(i - 1).clamp(0, n)];
    final p1  = pts[i];
    final p2  = pts[(i + 1).clamp(0, n)];
    final p3  = pts[(i + 2).clamp(0, n)];
    final f2  = f * f;
    final f3  = f2 * f;
    return Offset(
      0.5 * (2 * p1.dx + (-p0.dx + p2.dx) * f +
          (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * f2 +
          (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * f3),
      0.5 * (2 * p1.dy + (-p0.dy + p2.dy) * f +
          (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * f2 +
          (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * f3),
    );
  }

  void _stream(
    Canvas canvas,
    Size size, {
    required Color color,
    required int seed,
    required List<Offset> pts,
    required double spread,
    required int count,
    required double phase,
  }) {
    final rng   = math.Random(seed);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final prog = (i / count + phase * 0.10) % 1.0;
      final c    = _catmull(pts, prog);

      // Perpendicular direction for scatter
      final c2 = _catmull(pts, (prog + 0.008).clamp(0, 1));
      final dx  = c2.dx - c.dx;
      final dy  = c2.dy - c.dy;
      final len = math.sqrt(dx * dx + dy * dy).clamp(0.001, 999.0);
      final s   = (rng.nextDouble() - 0.5) * spread;

      final px = c.dx + (-dy / len) * s + (rng.nextDouble() - 0.5) * 5;
      final py = c.dy + (dx  / len) * s + (rng.nextDouble() - 0.5) * 5;

      final fade = math.sin(prog * math.pi).clamp(0.0, 1.0);
      final opa  = (fade * (rng.nextDouble() * 0.65 + 0.08)).clamp(0.0, 0.75);
      final r    = rng.nextDouble() * 1.6 + 0.35;

      paint.color = color.withValues(alpha: opa);
      canvas.drawCircle(Offset(px, py), r, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Background gradient
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kBg, _kBgEnd],
        ).createShader(Offset.zero & size),
    );

    // Cyan stream — lower-left → upper-center
    _stream(canvas, size,
        color: _kCyan,
        seed: 17,
        pts: [
          Offset(size.width * -0.06, size.height * 0.92),
          Offset(size.width *  0.08, size.height * 0.66),
          Offset(size.width *  0.20, size.height * 0.40),
          Offset(size.width *  0.34, size.height * 0.18),
          Offset(size.width *  0.52, size.height * 0.06),
        ],
        spread: 32,
        count: 240,
        phase: t);

    // Magenta stream — upper-right → lower-right
    _stream(canvas, size,
        color: _kMagenta,
        seed: 31,
        pts: [
          Offset(size.width * 1.06,  size.height * 0.08),
          Offset(size.width * 0.88,  size.height * 0.26),
          Offset(size.width * 0.77,  size.height * 0.50),
          Offset(size.width * 0.72,  size.height * 0.72),
          Offset(size.width * 0.82,  size.height * 0.90),
        ],
        spread: 26,
        count: 190,
        phase: t + 0.42);
  }

  @override
  bool shouldRepaint(_BgPainter o) => o.t != t;
}

// ══════════════════════════════════════════════════════════════════════════════
// LogoWidget — three concentric segmented arcs, cyan → purple + glow
// ══════════════════════════════════════════════════════════════════════════════
class LogoWidget extends StatelessWidget {
  final double t;
  const LogoWidget({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      height: 148,
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter();

  Color _colorAtAngle(double angle) {
    // top = cyan, bottom = purple
    final n = ((angle + math.pi / 2) / math.pi).clamp(0.0, 1.0);
    return Color.lerp(_kCyan, _kPurple, n)!;
  }

  void _ring(Canvas canvas, Offset c, double r, double sw,
      {int segs = 4, double gapFrac = 0.055}) {
    const full = math.pi * 2;
    final gap  = full * gapFrac;
    final seg  = (full - segs * gap) / segs;

    for (int i = 0; i < segs; i++) {
      final start = -math.pi / 2 + i * (seg + gap);
      final mid   = start + seg / 2;
      final col   = _colorAtAngle(mid);

      // Glow
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start, seg, false,
        Paint()
          ..color       = col.withValues(alpha: 0.32)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = sw + 8
          ..strokeCap   = StrokeCap.round
          ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      // Arc
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start, seg, false,
        Paint()
          ..color       = col
          ..style       = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap   = StrokeCap.round,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);

    // Ambient glow behind logo
    canvas.drawCircle(c, 70,
        Paint()
          ..shader = RadialGradient(colors: [
            _kCyan.withValues(alpha: 0.13),
            _kPurple.withValues(alpha: 0.07),
            Colors.transparent,
          ]).createShader(Rect.fromCircle(center: c, radius: 70)));

    _ring(canvas, c, 64, 3.5);                         // outer
    _ring(canvas, c, 46, 3.5, gapFrac: 0.06);          // middle
    _ring(canvas, c, 27, 3.5, gapFrac: 0.07);          // inner

    // Centre dot with glow
    canvas.drawCircle(c, 12,
        Paint()..color = _kCyan.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawCircle(c, 5, Paint()..color = _kCyan);
  }

  @override
  bool shouldRepaint(_LogoPainter o) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// _Separator — gradient line + centre diamond
// ══════════════════════════════════════════════════════════════════════════════
class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 72, height: 10, child: CustomPaint(painter: _SepPainter()));
}

class _SepPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cy   = size.height / 2;
    final mx   = size.width  / 2;
    const gap  = 8.0;

    canvas.drawLine(Offset(0, cy), Offset(mx - gap, cy),
        Paint()
          ..shader = LinearGradient(
            colors: [Colors.transparent, _kCyan.withValues(alpha: 0.65)],
          ).createShader(Rect.fromLTWH(0, cy - 1, mx - gap, 2))
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke);

    canvas.drawLine(Offset(mx + gap, cy), Offset(size.width, cy),
        Paint()
          ..shader = LinearGradient(
            colors: [_kPurple.withValues(alpha: 0.65), Colors.transparent],
          ).createShader(
              Rect.fromLTWH(mx + gap, cy - 1, mx - gap, 2))
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke);

    // Diamond
    final d = Path()
      ..moveTo(mx, cy - 3.5)
      ..lineTo(mx + 3.5, cy)
      ..lineTo(mx, cy + 3.5)
      ..lineTo(mx - 3.5, cy)
      ..close();
    canvas.drawPath(d,
        Paint()
          ..shader = const LinearGradient(colors: [_kCyan, _kPurple])
              .createShader(Rect.fromLTWH(mx - 4, cy - 4, 8, 8))
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_SepPainter o) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// HeroImageSection — floating PNG product image with ambient glow
// Asset: assets/images/hat.png  (transparent-background PNG, ~2:1.5 aspect)
// ══════════════════════════════════════════════════════════════════════════════
class HeroImageSection extends StatelessWidget {
  final double t; // 0–1 from the animation controller for the float effect
  const HeroImageSection({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    final w     = MediaQuery.of(context).size.width;
    final imgW  = w * 0.78;
    // Gentle vertical float: ±6 px sine wave
    final float = math.sin(t * math.pi * 2) * 6.0;

    return Center(
      child: Transform.translate(
        offset: Offset(0, float),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Diffuse blue glow beneath the hat for the "floating on surface" feel
            Positioned(
              bottom: -12,
              child: Container(
                width: imgW * 0.72,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1040DD).withValues(alpha: 0.45),
                      blurRadius: 36,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
            ),

            // Product image — transparent PNG, no distortion
            Image.asset(
              'assets/images/hat.png',
              width: imgW,
              fit: BoxFit.contain,
              // Fallback while asset is not yet bundled
              errorBuilder: (_, __, ___) => const _HatPlaceholder(),
            ),
          ],
        ),
      ),
    );
  }
}

// Minimal placeholder shown if the PNG has not been added to assets yet
class _HatPlaceholder extends StatelessWidget {
  const _HatPlaceholder();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Container(
      width: w * 0.78,
      height: w * 0.52,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1520),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCyan.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined,
              color: _kCyan.withValues(alpha: 0.35), size: 40),
          const SizedBox(height: 8),
          Text(
            'assets/images/hat.png',
            style: TextStyle(
              color: _kGray.withValues(alpha: 0.6),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dead code below — kept only until assets/images/hat.png is confirmed
//    present; safe to delete once the PNG ships.
// ignore: unused_element
class _HatPainter extends CustomPainter {
  final double t;
  _HatPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w  = size.width;
    final h  = size.height;
    final cx = w * 0.50;
    final cy = h * 0.46;

    // ── Ground reflection glow ──────────────────────────────────────────────
    final groundRect = Rect.fromCenter(
      center: Offset(cx, h * 0.84),
      width: w * 0.62, height: h * 0.10,
    );
    canvas.drawOval(groundRect,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFF2040AA).withValues(alpha: 0.26),
            Colors.transparent,
          ]).createShader(groundRect));

    // ── Cap crown ───────────────────────────────────────────────────────────
    final cL   = cx - w * 0.270;
    final cR   = cx + w * 0.245;
    final cTop = cy - h * 0.390;
    final cBot = cy + h * 0.095;

    final crown = Path()
      ..moveTo(cL + 16, cBot)
      ..quadraticBezierTo(cL - 6, cBot - 14, cL + 4, cy - h * 0.10)
      ..quadraticBezierTo(cL + 6, cTop + 20, cx - w * 0.04, cTop)
      ..quadraticBezierTo(cx + w * 0.08, cTop - 2, cR - 6, cTop + 14)
      ..quadraticBezierTo(cR + 6, cy - h * 0.08, cR, cBot - 8)
      ..lineTo(cL + 16, cBot)
      ..close();

    canvas.drawPath(crown,
        Paint()..color = const Color(0xFF060810)..style = PaintingStyle.fill);
    canvas.drawPath(crown,
        Paint()
          ..color = const Color(0xFF18223A).withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);

    // ── Brim ─────────────────────────────────────────────────────────────────
    final brimY   = cBot - 4;
    final brimPath = Path()
      ..moveTo(cL + 16, brimY + 2)
      ..quadraticBezierTo(cL - 14, brimY, cx - w * 0.46, brimY + 8)
      ..lineTo(cx - w * 0.47, brimY + 20)
      ..quadraticBezierTo(cL - 10, brimY + 24, cL + 14, brimY + 16)
      ..close();
    canvas.drawPath(brimPath,
        Paint()..color = const Color(0xFF07090F)..style = PaintingStyle.fill);

    // ── LED panel ────────────────────────────────────────────────────────────
    final lL = cx - w * 0.148;
    final lT = cy - h * 0.268;
    final lR = cx + w * 0.162;
    final lB = cy + h * 0.072;
    final lW = lR - lL;
    final lH = lB - lT;

    final panRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(lL, lT, lR, lB), const Radius.circular(4));

    // Panel surface
    canvas.drawRRect(panRect,
        Paint()..color = const Color(0xFF030509)..style = PaintingStyle.fill);
    // Panel LED ambient glow
    canvas.drawRRect(panRect,
        Paint()
          ..color = const Color(0xFF0B24BB).withValues(alpha: 0.22)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));

    // ── LED dot matrix ────────────────────────────────────────────────────────
    const cols = 10;
    const rows = 10;
    final cW   = lW / (cols + 1);
    final cH   = lH / (rows + 1);
    final dp   = Paint()..style = PaintingStyle.fill;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final px = lL + (c + 1) * cW;
        final py = lT + (r + 1) * cH;

        final dc   = c - (cols - 1) / 2.0;
        final dr   = r - (rows - 1) / 2.0;
        final dist = math.sqrt(dc * dc + dr * dr);
        final maxD = math.sqrt(math.pow((cols - 1) / 2.0, 2) +
            math.pow((rows - 1) / 2.0, 2));
        final nd   = (dist / maxD).clamp(0.0, 1.0);

        // Outward ripple animation
        final wave = (math.sin(dist * 1.15 - t * math.pi * 2 * 1.6) + 1) / 2;

        final hue = 210 + nd * 68;  // blue → purple
        final sat = 0.75 + wave * 0.25;
        final val = 0.55 + wave * 0.45;
        final opa = ((1 - nd * 0.22) * (0.38 + wave * 0.62)).clamp(0.15, 1.0);

        final col = HSVColor.fromAHSV(opa, hue, sat, val).toColor();

        // Glow halo
        dp.color      = col.withValues(alpha: opa * 0.5);
        dp.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
        canvas.drawCircle(Offset(px, py), cW * 0.40, dp);

        // Core
        dp.maskFilter = null;
        dp.color      = col;
        canvas.drawCircle(Offset(px, py), cW * 0.22, dp);
      }
    }

    // ── Muse headband strip ──────────────────────────────────────────────────
    final mL    = cL + 8;
    final mR    = cR - 6;
    final mY    = cBot + 2;
    final mH    = h * 0.046;
    final mRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(mL, mY, mR, mY + mH),
      Radius.circular(mH / 2),
    );
    canvas.drawRRect(mRect,
        Paint()..color = const Color(0xFF0C1220)..style = PaintingStyle.fill);
    canvas.drawRRect(mRect,
        Paint()
          ..color = const Color(0xFF1E2F60).withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);

    // Muse LED status lights
    for (int i = 0; i < 3; i++) {
      final ix     = mR - 14 - i * 12.0;
      final iy     = mY + mH / 2;
      final pulse  = (math.sin(t * math.pi * 2 + i * 1.3) + 1) / 2;
      canvas.drawCircle(
        Offset(ix, iy), 3.5,
        Paint()
          ..color = i == 0
              ? const Color(0xFF55AAFF).withValues(alpha: 0.55 + pulse * 0.45)
              : Colors.white.withValues(alpha: 0.20 + pulse * 0.18),
      );
    }
  }

  @override
  bool shouldRepaint(_HatPainter o) => o.t != t;
}

// ══════════════════════════════════════════════════════════════════════════════
// PaginationDots — 5 dots, first is an active cyan pill
// ══════════════════════════════════════════════════════════════════════════════
class PaginationDots extends StatelessWidget {
  final int current;
  final int total;
  const PaginationDots({super.key, required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width:  active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? _kCyan : _kDotInact,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GradientButton — "Get Started" (cyan → purple with dual glow)
// ══════════════════════════════════════════════════════════════════════════════
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const GradientButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kCyan, _kPurple],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _kCyan.withValues(alpha: 0.26),
              blurRadius: 22,
              offset: const Offset(0, 4),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: _kPurple.withValues(alpha: 0.20),
              blurRadius: 30,
              offset: const Offset(0, 12),
              spreadRadius: -8,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: _kWhite,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SentioOutlineButton — "Log In" (transparent, cyan border)
// ══════════════════════════════════════════════════════════════════════════════
class SentioOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const SentioOutlineButton(
      {super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _kCyan.withValues(alpha: 0.55),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: _kCyan,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
