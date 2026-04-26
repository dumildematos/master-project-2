import 'package:flutter/material.dart';
import '../models/sentio_state.dart';
import '../theme/theme.dart';

const _kBands = [
  ('alpha', 'α  Alpha', kCyan,          'calm / relaxed'),
  ('beta',  'β  Beta',  kAmber,          'focus / alertness'),
  ('theta', 'θ  Theta', kMagenta,        'creativity / drowsiness'),
  ('gamma', 'γ  Gamma', Color(0xFFF97316), 'cognition / excitement'),
  ('delta', 'δ  Delta', Color(0xFF8B5CF6), 'deep rest'),
];

class BandBars extends StatelessWidget {
  final SentioState data;
  final bool showDesc;

  const BandBars({super.key, required this.data, this.showDesc = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _kBands.map((band) {
        final (key, label, color, desc) = band;
        final value = switch (key) {
          'alpha' => data.alpha,
          'beta'  => data.beta,
          'theta' => data.theta,
          'gamma' => data.gamma,
          'delta' => data.delta,
          _       => 0.0,
        };
        final pct = (value * 100).clamp(0, 100).round();

        return Padding(
          padding: const EdgeInsets.only(bottom: kSm),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                      style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12, color: kText,
                      )),
                    if (showDesc)
                      Text(desc,
                        style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 9, color: kMuted,
                        )),
                  ],
                ),
              ),
              const SizedBox(width: kSm),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 7,
                    child: LinearProgressIndicator(
                      value: value.clamp(0, 1),
                      backgroundColor: kBorder,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: kSm),
              SizedBox(
                width: 36,
                child: Text('$pct%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12, color: kMuted,
                  )),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
