import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sentio_provider.dart';
import '../models/sentio_state.dart';
import '../widgets/emotion_ring.dart';
import '../widgets/band_bars.dart';
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

          // ── Connection banner (only when not streaming) ─────────────────
          if (!sentio.connected || !sentio.hasSignal)
            _ConnectionBanner(
              connected: sentio.connected,
              hasSignal: sentio.hasSignal,
            ),

          // ── Emotion ring ────────────────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: kLg),
              child: EmotionRing(
                emotion:    data.emotion,
                confidence: data.confidence / 100,
                size:       240,
              ),
            ),
          ),

          // ── EEG waveform bars ───────────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: kXl),
              child: _EegWaveform(
                alpha: data.alpha,
                beta:  data.beta,
                active: sentio.hasSignal,
              ),
            ),
          ),

          // ── AI Guidance ─────────────────────────────────────────────────
          _AiGuidanceCard(
            text:      data.aiGuidance,
            connected: sentio.connected,
          ),
          const SizedBox(height: kMd),

          // ── EEG Bands ───────────────────────────────────────────────────
          _DashCard(
            header: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _SectionLabel('EEG BANDS'),
                Text('Hz Range',
                  style: TextStyle(
                    fontFamily: 'monospace', fontSize: 11,
                    color: kMuted, letterSpacing: 1,
                  )),
              ],
            ),
            child: BandBars(data: data),
          ),
          const SizedBox(height: kMd),

          // ── Signal + Vitals (side by side) ──────────────────────────────
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon:  Icons.sensors,
                  label: 'SIGNAL',
                  items: [
                    _MetricItem('QUALITY', '${data.signalQuality.toStringAsFixed(0)}%'),
                    _MetricItem('MINDFUL',
                      data.mindfulness != null
                          ? '${(data.mindfulness! * 100).toStringAsFixed(0)}%'
                          : '—'),
                  ],
                ),
              ),
              const SizedBox(width: kMd),
              Expanded(
                child: _MetricCard(
                  icon:  Icons.favorite_outline,
                  label: 'VITALS',
                  iconColor: const Color(0xFF4ADE80),
                  items: [
                    _MetricItem('HEART BPM',
                      data.vitals.heartBpm?.toStringAsFixed(0) ?? '—'),
                    _MetricItem('RESP RPM',
                      data.vitals.respirationRpm?.toStringAsFixed(0) ?? '—'),
                  ],
                ),
              ),
            ],
          ),

          // ── AI Pattern ──────────────────────────────────────────────────
          if (data.aiPattern != null) ...[
            const SizedBox(height: kMd),
            _AiPatternCard(pattern: data.aiPattern!),
          ],
        ],
      ),
    );
  }
}

// ── EEG Waveform ───────────────────────────────────────────────────────────────
class _EegWaveform extends StatefulWidget {
  final double alpha;
  final double beta;
  final bool   active;
  const _EegWaveform({required this.alpha, required this.beta, required this.active});

  @override
  State<_EegWaveform> createState() => _EegWaveformState();
}

class _EegWaveformState extends State<_EegWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  static const _bars = 9;
  // Phase offsets so each bar animates independently
  final _phases = List.generate(_bars, (i) => i * pi / (_bars - 1));

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value * 2 * pi;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(_bars, (i) {
            final base = 0.25 + widget.alpha * 0.4 + widget.beta * 0.2;
            final h = widget.active
                ? (base + sin(t + _phases[i]) * 0.35).clamp(0.08, 1.0)
                : 0.15 + (i % 3 == 0 ? 0.05 : 0.0);
            return Container(
              width: 4, height: 48 * h,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: kCyan.withOpacity(0.55 + h * 0.45),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── AI Guidance card ───────────────────────────────────────────────────────────
class _AiGuidanceCard extends StatelessWidget {
  final String? text;
  final bool    connected;
  const _AiGuidanceCard({required this.text, required this.connected});

  @override
  Widget build(BuildContext context) {
    final hasContent = text != null;
    return Container(
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent bar
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: hasContent ? kMagenta : kBorder,
                borderRadius: const BorderRadius.only(
                  topLeft:    Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(kMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('✦ ',
                        style: TextStyle(color: kMagenta, fontSize: 12)),
                      const Text('AI GUIDANCE',
                        style: TextStyle(
                          fontFamily: 'monospace', fontSize: 10,
                          letterSpacing: 2, color: kMagenta,
                          fontWeight: FontWeight.bold,
                        )),
                      const Spacer(),
                      Icon(Icons.auto_awesome,
                        size: 14, color: kMagenta.withOpacity(0.7)),
                    ]),
                    const SizedBox(height: kSm),
                    Text(
                      hasContent
                          ? '"$text"'
                          : (connected ? 'Generating guidance…' : 'Not connected'),
                      style: TextStyle(
                        fontSize: 15, height: 1.6,
                        color: hasContent ? kText : kMuted,
                        fontStyle: hasContent ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Generic dashboard card with optional header ────────────────────────────────
class _DashCard extends StatelessWidget {
  final Widget? header;
  final Widget  child;
  const _DashCard({required this.child, this.header});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(kMd),
    decoration: BoxDecoration(
      color: kBg2,
      border: Border.all(color: kBorder),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null) ...[header!, const SizedBox(height: kMd)],
        child,
      ],
    ),
  );
}

// ── Metric card (SIGNAL / VITALS) ──────────────────────────────────────────────
class _MetricItem {
  final String label, value;
  const _MetricItem(this.label, this.value);
}

class _MetricCard extends StatelessWidget {
  final IconData        icon;
  final String          label;
  final Color           iconColor;
  final List<_MetricItem> items;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.items,
    this.iconColor = kCyan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kMd),
      decoration: BoxDecoration(
        color: kBg2,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Text(label,
              style: const TextStyle(
                fontFamily: 'monospace', fontSize: 10,
                letterSpacing: 2, color: kMuted,
                fontWeight: FontWeight.bold,
              )),
          ]),
          const SizedBox(height: kMd),
          Row(
            children: items.map((item) => Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label,
                    style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 9,
                      color: kMuted, letterSpacing: 1,
                    )),
                  const SizedBox(height: 4),
                  Text(item.value,
                    style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 20,
                      fontWeight: FontWeight.bold, color: kText,
                    )),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

// ── AI Pattern card ────────────────────────────────────────────────────────────
class _AiPatternCard extends StatelessWidget {
  final AiPattern pattern;
  const _AiPatternCard({required this.pattern});

  @override
  Widget build(BuildContext context) {
    final primary = _hex(pattern.primary);

    return Container(
      decoration: BoxDecoration(
        color: kBg2,
        border: Border.all(color: primary.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(kMd, kMd, kMd, 0),
            child: Row(children: [
              Icon(Icons.star_rounded, size: 16, color: primary),
              const SizedBox(width: 8),
              Text(
                'AI PATTERN: ${pattern.patternType.toUpperCase()}',
                style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 11,
                  fontWeight: FontWeight.bold, color: kText, letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: primary.withOpacity(0.4)),
                ),
                child: Text('ACTIVE',
                  style: TextStyle(
                    fontFamily: 'monospace', fontSize: 9,
                    fontWeight: FontWeight.bold, color: primary, letterSpacing: 1,
                  )),
              ),
            ]),
          ),

          // Metrics
          Padding(
            padding: const EdgeInsets.all(kMd),
            child: Row(
              children: [
                _PatternMetric('SPEED',      '${(pattern.speed * 100).toStringAsFixed(0)}%'),
                _PatternMetric('COMPLEXITY', '${(pattern.complexity * 100).toStringAsFixed(0)}%'),
                _PatternMetric('INTENSITY',  '${(pattern.intensity * 100).toStringAsFixed(0)}%'),
              ],
            ),
          ),

          // Color palette + preview strip
          Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
              gradient: LinearGradient(
                colors: [
                  _hex(pattern.shadow),
                  _hex(pattern.primary).withOpacity(0.6),
                  _hex(pattern.secondary).withOpacity(0.4),
                  _hex(pattern.accent).withOpacity(0.3),
                  _hex(pattern.shadow),
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final c in [pattern.primary, pattern.secondary, pattern.accent, pattern.shadow])
                  Container(
                    width: 18, height: 18,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _hex(c),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternMetric extends StatelessWidget {
  final String label, value;
  const _PatternMetric(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(label,
          style: const TextStyle(
            fontFamily: 'monospace', fontSize: 9,
            color: kMuted, letterSpacing: 1,
          )),
        const SizedBox(height: 4),
        Text(value,
          style: const TextStyle(
            fontFamily: 'monospace', fontSize: 20,
            fontWeight: FontWeight.bold, color: kText,
          )),
      ],
    ),
  );
}

// ── Connection banner ──────────────────────────────────────────────────────────
class _ConnectionBanner extends StatelessWidget {
  final bool connected, hasSignal;
  const _ConnectionBanner({required this.connected, required this.hasSignal});

  @override
  Widget build(BuildContext context) {
    final isWaiting = connected && !hasSignal;
    return Container(
      margin: const EdgeInsets.only(bottom: kMd),
      padding: const EdgeInsets.symmetric(horizontal: kMd, vertical: kSm),
      decoration: BoxDecoration(
        color: kBg2,
        border: Border.all(color: isWaiting ? kAmber.withOpacity(0.3) : kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: isWaiting ? kAmber : kMuted,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            !connected
                ? 'Not connected — check backend address in Settings'
                : 'Connected · waiting for EEG stream',
            style: const TextStyle(
              fontFamily: 'monospace', fontSize: 11, color: kMuted,
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(
      fontFamily: 'monospace', fontSize: 11,
      fontWeight: FontWeight.bold, color: kCyan, letterSpacing: 2,
    ));
}

// ── Helpers ────────────────────────────────────────────────────────────────────
Color _hex(String hex) {
  try {
    final s = hex.replaceAll('#', '');
    return Color(int.parse(s.length == 6 ? 'FF$s' : s, radix: 16));
  } catch (_) {
    return kMuted;
  }
}
