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
    this.size = 220,
  });

  @override
  State<EmotionRing> createState() => _EmotionRingState();
}

class _EmotionRingState extends State<EmotionRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _buildAnimation();
  }

  @override
  void didUpdateWidget(EmotionRing old) {
    super.didUpdateWidget(old);
    if (old.emotion != widget.emotion || old.confidence != widget.confidence) {
      _ctrl.dispose();
      _buildAnimation();
    }
  }

  void _buildAnimation() {
    final speed = 800 + ((1 - widget.confidence) * 1200).round();
    _ctrl = AnimationController(
      vsync: this, duration: Duration(milliseconds: speed),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.3, end: 0.9).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final col       = emotionColor(widget.emotion);
    final ringSize  = widget.size;
    final innerSize = ringSize * 0.72;

    return SizedBox(
      width: ringSize, height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulsing ring
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Container(
                  width: ringSize, height: ringSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: col, width: 2),
                  ),
                ),
              ),
            ),
          ),

          // Inner filled circle
          Container(
            width: innerSize, height: innerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: col.withOpacity(0.10),
              border: Border.all(color: col.withOpacity(0.33)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  emotionLabel(widget.emotion).toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'monospace', fontSize: 22,
                    fontWeight: FontWeight.w800, color: col, letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(widget.confidence * 100).round()}%',
                  style: TextStyle(
                    fontFamily: 'monospace', fontSize: 14,
                    color: col.withOpacity(0.73),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
