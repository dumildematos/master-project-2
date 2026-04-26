import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sentio_provider.dart';
import '../models/sentio_state.dart';
import '../widgets/connection_banner.dart';
import '../theme/theme.dart';

const _kBandMeta = [
  ('alpha', 'α Alpha', kCyan),
  ('beta',  'β Beta',  kAmber),
  ('theta', 'θ Theta', kMagenta),
  ('gamma', 'γ Gamma', Color(0xFFF97316)),
  ('delta', 'δ Delta', Color(0xFF8B5CF6)),
];

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sentio    = context.watch<SentioProvider>();
    final recent    = sentio.history.length > 60
        ? sentio.history.sublist(sentio.history.length - 60)
        : sentio.history;
    final emotions  = sentio.emotionHistory;

    const titleStyle = TextStyle(
      fontFamily: 'monospace', fontSize: 10, letterSpacing: 2, color: kMuted,
    );
    const emptyStyle = TextStyle(
      fontFamily: 'monospace', fontSize: 13, color: kMuted,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(kMd, kMd, kMd, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConnectionBanner(connected: sentio.connected, hasSignal: sentio.hasSignal),

          // ── EEG Band History ──
          Text('EEG BAND HISTORY · last ${recent.length} frames',
            style: titleStyle),
          const SizedBox(height: kSm),
          if (recent.isEmpty)
            const Text('No data yet — waiting for EEG signal…', style: emptyStyle)
          else
            Container(
              decoration: BoxDecoration(
                color: kBg2,
                border: Border.all(color: kBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(kMd),
              child: Column(
                children: _kBandMeta.map((m) {
                  final (key, label, color) = m;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: kSm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                          style: TextStyle(
                            fontFamily: 'monospace', fontSize: 11, color: color,
                          )),
                        const SizedBox(height: 4),
                        _Sparkline(band: key, data: recent, color: color),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: kLg),

          // ── Emotion Timeline ──
          Text('EMOTION TIMELINE · last ${emotions.length} changes',
            style: titleStyle),
          const SizedBox(height: kSm),
          if (emotions.isEmpty)
            const Text('No emotion changes recorded yet…', style: emptyStyle)
          else
            Column(
              children: emotions.reversed
                  .map((e) => _EmotionPill(entry: e))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

// ── Sparkline ──────────────────────────────────────────────────────────────────
class _Sparkline extends StatelessWidget {
  final String band;
  final List<BandHistory> data;
  final Color color;

  const _Sparkline({required this.band, required this.data, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 60,
    child: CustomPaint(
      painter: _SparklinePainter(band: band, data: data, color: color),
      size: const Size(double.infinity, 60),
    ),
  );
}

class _SparklinePainter extends CustomPainter {
  final String band;
  final List<BandHistory> data;
  final Color color;
  const _SparklinePainter({
    required this.band, required this.data, required this.color,
  });

  double _val(BandHistory h) => switch (band) {
    'alpha' => h.alpha, 'beta'  => h.beta,
    'theta' => h.theta, 'gamma' => h.gamma,
    'delta' => h.delta, _       => 0.0,
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const gap     = 2.0;
    final barW    = ((size.width - (data.length - 1) * gap) / data.length).clamp(2.0, 20.0);
    final paint   = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final val  = _val(data[i]).clamp(0.0, 1.0);
      final barH = (val * size.height).clamp(2.0, size.height);
      final x    = i * (barW + gap);
      paint.color = color.withOpacity(0.55 + val * 0.45);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - barH, barW, barH),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.band != band || old.data != data;
}

// ── Emotion pill ───────────────────────────────────────────────────────────────
class _EmotionPill extends StatelessWidget {
  final EmotionHistoryEntry entry;
  const _EmotionPill({required this.entry});

  @override
  Widget build(BuildContext context) {
    final col  = emotionColor(entry.emotion);
    final time = TimeOfDay.fromDateTime(
      DateTime.fromMillisecondsSinceEpoch(entry.timestamp),
    ).format(context);

    return Container(
      margin: const EdgeInsets.only(bottom: kXs),
      padding: const EdgeInsets.all(kSm),
      decoration: BoxDecoration(
        color: kBg2,
        border: Border.all(color: col.withOpacity(0.27)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: col, shape: BoxShape.circle),
          ),
          const SizedBox(width: kSm),
          Expanded(
            child: Text(
              emotionLabel(entry.emotion),
              style: TextStyle(
                fontFamily: 'monospace', fontSize: 13,
                fontWeight: FontWeight.bold, color: col,
              ),
            ),
          ),
          Text(
            '${entry.confidence.round()}%',
            style: const TextStyle(
              fontFamily: 'monospace', fontSize: 12, color: kMuted,
            ),
          ),
          const SizedBox(width: kSm),
          Text(
            time,
            style: const TextStyle(
              fontFamily: 'monospace', fontSize: 11, color: kMuted,
            ),
          ),
        ],
      ),
    );
  }
}
