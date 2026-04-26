import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sentio_provider.dart';
import '../widgets/emotion_ring.dart';
import '../widgets/band_bars.dart';
import '../widgets/stat_row.dart';
import '../widgets/connection_banner.dart';
import '../theme/theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sentio = context.watch<SentioProvider>();
    final data   = sentio.data;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(kMd, kMd, kMd, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConnectionBanner(connected: sentio.connected, hasSignal: sentio.hasSignal),

          // Emotion ring
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: kLg),
              child: Column(
                children: [
                  EmotionRing(
                    emotion:    data.emotion,
                    confidence: data.confidence / 100,
                    size:       220,
                  ),
                  if (data.isUncertain && sentio.hasSignal) ...[
                    const SizedBox(height: kSm),
                    const Text(
                      'Low confidence — uncertain state',
                      style: TextStyle(
                        fontFamily: 'monospace', fontSize: 12, color: kMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // AI Guidance
          _Card(
            borderColor: data.aiGuidance != null ? kMagenta.withOpacity(0.2) : kBorder,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✦ AI GUIDANCE · claude-haiku-4-5',
                  style: TextStyle(
                    fontFamily: 'monospace', fontSize: 10,
                    letterSpacing: 2, color: kMagenta,
                  )),
                const SizedBox(height: kSm),
                Text(
                  data.aiGuidance ??
                      (sentio.connected ? 'Generating guidance…' : 'Not connected'),
                  style: TextStyle(
                    fontSize: 15,
                    color: data.aiGuidance != null ? kText : kMuted,
                    fontStyle: FontStyle.italic,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: kMd),

          // EEG Bands
          _Section(title: 'EEG BANDS',
            child: BandBars(data: data)),

          // Signal
          _Section(title: 'SIGNAL',
            child: StatRow(items: [
              StatItem(label: 'QUALITY',  value: data.signalQuality.toStringAsFixed(0), unit: '%'),
              StatItem(label: 'MINDFUL',  value: data.mindfulness != null ? (data.mindfulness! * 100).toStringAsFixed(0) : null, unit: '%'),
              StatItem(label: 'RESTFUL',  value: data.restfulness != null ? (data.restfulness! * 100).toStringAsFixed(0) : null, unit: '%'),
            ])),

          // Vitals
          _Section(title: 'VITALS',
            child: StatRow(items: [
              StatItem(label: 'HEART BPM', value: data.vitals.heartBpm?.toStringAsFixed(0)),
              StatItem(label: 'RESP RPM',  value: data.vitals.respirationRpm?.toStringAsFixed(1)),
              StatItem(label: 'HR CONF',   value: data.vitals.heartConfidence != null ? (data.vitals.heartConfidence! * 100).toStringAsFixed(0) : null, unit: '%'),
            ])),

          // AI Pattern
          if (data.aiPattern != null) ...[
            _Section(title: 'AI PATTERN',
              child: _Card(
                borderColor: _parseColor(data.aiPattern!.primary).withOpacity(0.27),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          data.aiPattern!.patternType.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 14,
                            fontWeight: FontWeight.bold, color: kText, letterSpacing: 2,
                          ),
                        ),
                        Row(
                          children: [
                            data.aiPattern!.primary,
                            data.aiPattern!.secondary,
                            data.aiPattern!.accent,
                            data.aiPattern!.shadow,
                          ].map((c) => Container(
                            width: 20, height: 20, margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: _parseColor(c),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: kSm),
                    StatRow(items: [
                      StatItem(label: 'SPEED',      value: (data.aiPattern!.speed * 100).toStringAsFixed(0), unit: '%'),
                      StatItem(label: 'COMPLEXITY', value: (data.aiPattern!.complexity * 100).toStringAsFixed(0), unit: '%'),
                      StatItem(label: 'INTENSITY',  value: (data.aiPattern!.intensity * 100).toStringAsFixed(0), unit: '%'),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Color _parseColor(String hex) {
  try {
    final s = hex.replaceAll('#', '');
    return Color(int.parse(s.length == 6 ? 'FF$s' : s, radix: 16));
  } catch (_) {
    return kMuted;
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: kMd),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
          style: const TextStyle(
            fontFamily: 'monospace', fontSize: 10,
            letterSpacing: 2, color: kMuted,
          )),
        const SizedBox(height: kSm),
        child,
      ],
    ),
  );
}

class _Card extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  const _Card({required this.child, required this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(kMd),
    decoration: BoxDecoration(
      color: kBg2,
      border: Border.all(color: borderColor),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}
