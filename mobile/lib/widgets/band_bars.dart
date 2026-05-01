import 'package:flutter/material.dart';
import '../models/sentio_state.dart';
import '../theme/theme.dart';

const _kBands = [
  ('alpha', 'ALPHA', kCyan,              '8–13 Hz'),
  ('beta',  'BETA',  kAmber,             '13–30 Hz'),
  ('theta', 'THETA', Color(0xFFDD22FF),   '4–8 Hz'),
  ('gamma', 'GAMMA', Color(0xFFF97316),  '30–100 Hz'),
  ('delta', 'DELTA', Color(0xFF8B5CF6),  '1–4 Hz'),
];

class BandBars extends StatelessWidget {
  final SentioState data;
  const BandBars({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _kBands.map((band) {
        final (key, label, color, hz) = band;
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
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                    style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 11,
                      fontWeight: FontWeight.bold, color: kText, letterSpacing: 1,
                    )),
                  Text('$pct%',
                    style: TextStyle(
                      fontFamily: 'monospace', fontSize: 12,
                      fontWeight: FontWeight.bold, color: color,
                    )),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 5,
                  child: LinearProgressIndicator(
                    value: value.clamp(0.0, 1.0),
                    backgroundColor: kBorder,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
