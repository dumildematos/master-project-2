import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/theme.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
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
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Brand header ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(kMd, kLg, kMd, 0),
              child: Row(children: [
                const Text('SENTIO',
                  style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold,
                    color: kCyan, letterSpacing: 4,
                  )),
                const SizedBox(width: kSm),
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(color: kCyan, shape: BoxShape.circle),
                ),
              ]),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kMd),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text('Mind. Tech. Expression.',
                  style: TextStyle(color: kMuted, fontSize: 12, letterSpacing: 1.5)),
              ),
            ),

            // ── Hero illustration ──────────────────────────────────────
            Expanded(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => CustomPaint(
                  size: Size(double.infinity, h * 0.45),
                  painter: _SplashPainter(_pulse.value),
                ),
              ),
            ),

            // ── Bottom section ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Real-time brainwave feedback.',
                    style: TextStyle(color: kText, fontSize: 20,
                        fontWeight: FontWeight.bold, height: 1.3)),
                  const SizedBox(height: 6),
                  const Text('Wear your mind.',
                    style: TextStyle(color: kCyan, fontSize: 16,
                        fontStyle: FontStyle.italic)),
                  const SizedBox(height: kXl),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kCyan,
                        foregroundColor: kBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const LoginScreen())),
                      child: const Text('Log In',
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: kSm),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kText,
                        side: const BorderSide(color: kBorder, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const LoginScreen())),
                      child: const Text('Sign Up',
                        style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: kXl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashPainter extends CustomPainter {
  final double t;
  _SplashPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Outer radial glow
    final glowR = size.width * 0.38 + t * 12;
    final glowPaint = Paint()
      ..shader = RadialGradient(colors: [
        kPurple.withOpacity(0.25 + t * 0.1),
        kCyan.withOpacity(0.08 + t * 0.04),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: glowR));
    canvas.drawCircle(Offset(cx, cy), glowR, glowPaint);

    // LED matrix grid (8x8 dots)
    const cols = 8;
    const rows = 8;
    final cellW = size.width * 0.55 / cols;
    final cellH = size.width * 0.55 / rows;
    final startX = cx - (cols / 2) * cellW;
    final startY = cy - (rows / 2) * cellH - size.height * 0.04;

    final rand = Random(42);
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final px = startX + c * cellW + cellW / 2;
        final py = startY + r * cellH + cellH / 2;
        final dist = sqrt(pow(r - 3.5, 2) + pow(c - 3.5, 2));
        final wave  = (sin(t * 2 * pi - dist * 0.9) + 1) / 2;
        final hue = 180 + rand.nextDouble() * 60;
        final color = HSVColor.fromAHSV(
          wave * 0.85 + 0.1, hue, 0.7 + wave * 0.3, 0.9).toColor();
        final rr = cellW * 0.28;

        // Glow
        canvas.drawCircle(Offset(px, py), rr * 2.2,
          Paint()..color = color.withOpacity(wave * 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        // Dot
        canvas.drawCircle(Offset(px, py), rr,
          Paint()..color = color);
      }
    }

    // Person silhouette (simple circles/oval suggesting head + hat)
    final headY = startY - cellH * 1.8;
    canvas.drawCircle(Offset(cx, headY), 22,
      Paint()..color = kBg2.withOpacity(0.9));
    canvas.drawCircle(Offset(cx, headY), 22,
      Paint()..color = kCyan.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);

    // Neural connection lines
    for (int i = 0; i < 6; i++) {
      final angle = (i / 6) * 2 * pi + t * pi;
      final x1 = cx + cos(angle) * 25;
      final y1 = headY + sin(angle) * 25;
      final x2 = cx + cos(angle) * (45 + t * 8);
      final y2 = headY + sin(angle) * (45 + t * 8);
      canvas.drawLine(
        Offset(x1, y1), Offset(x2, y2),
        Paint()
          ..color = kCyan.withOpacity(0.5 - t * 0.2)
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_SplashPainter old) => old.t != t;
}
