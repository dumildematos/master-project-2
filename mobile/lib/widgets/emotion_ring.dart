import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/theme.dart';

class EmotionRing extends StatefulWidget {
  final String emotion;
  final double confidence; // 0–1
  final double size;

  const EmotionRing({
    super.key,
    required this.emotion,
    required this.confidence,
    this.size = 240,
  });

  @override
  State<EmotionRing> createState() => _EmotionRingState();
}

class _EmotionRingState extends State<EmotionRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progress = Tween<double>(begin: 0, end: widget.confidence)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(EmotionRing old) {
    super.didUpdateWidget(old);
    if (old.confidence != widget.confidence || old.emotion != widget.emotion) {
      _progress = Tween<double>(
        begin: _progress.value,
        end:   widget.confidence,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final col = emotionColor(widget.emotion);
    final pct = (widget.confidence * 100).round();

    return SizedBox(
      width: widget.size, height: widget.size,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (_, __) => CustomPaint(
          painter: _ArcRingPainter(
            color:    col,
            progress: _progress.value,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  emotionLabel(widget.emotion).toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'monospace', fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: col, letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$pct',
                      style: TextStyle(
                        fontSize: 64, fontWeight: FontWeight.w800,
                        color: kText, height: 1.0,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '%',
                        style: TextStyle(
                          fontFamily: 'monospace', fontSize: 18,
                          fontWeight: FontWeight.bold, color: col,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcRingPainter extends CustomPainter {
  final Color color;
  final double progress; // 0–1

  const _ArcRingPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const stroke = 6.0;
    final radius = size.width / 2 - stroke - 4;
    final rect   = Rect.fromCircle(center: center, radius: radius);

    // Static inner ring
    canvas.drawCircle(
      center, radius * 0.84,
      Paint()
        ..color       = color.withOpacity(0.08)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Background track
    canvas.drawCircle(
      center, radius,
      Paint()
        ..color       = color.withOpacity(0.12)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    // Progress arc (starts at top, clockwise)
    if (progress > 0) {
      canvas.drawArc(
        rect, -pi / 2, progress * 2 * pi, false,
        Paint()
          ..color       = color
          ..style       = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap   = StrokeCap.round,
      );

      // Glow effect on the arc tip
      final tipAngle = -pi / 2 + progress * 2 * pi;
      final tipX = center.dx + radius * cos(tipAngle);
      final tipY = center.dy + radius * sin(tipAngle);
      canvas.drawCircle(
        Offset(tipX, tipY), stroke * 1.2,
        Paint()
          ..color      = color.withOpacity(0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(_ArcRingPainter old) =>
      old.progress != progress || old.color != color;
}
