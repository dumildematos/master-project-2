import 'dart:math';

import '../models/sentio_session.dart';
import 'emotion_classifier.dart';

class BrainwaveSimulator {
  final Random _rng = Random();
  double _phase = 0.0;

  BrainwaveSample next(String sessionId) {
    _phase += 0.04;

    final alpha = (0.30 + sin(_phase) * 0.14 + _rng.nextDouble() * 0.10).clamp(0.0, 1.0);
    final beta  = (0.26 + cos(_phase * 0.7) * 0.10 + _rng.nextDouble() * 0.10).clamp(0.0, 1.0);
    final theta = (0.20 + sin(_phase * 0.3) * 0.07 + _rng.nextDouble() * 0.08).clamp(0.0, 1.0);
    final delta = (0.15 + _rng.nextDouble() * 0.09).clamp(0.0, 1.0);
    final gamma = (0.09 + _rng.nextDouble() * 0.07).clamp(0.0, 1.0);
    final sq    = (0.75 + _rng.nextDouble() * 0.25).clamp(0.0, 1.0);

    final result = EmotionClassifier.classify(
      delta: delta, theta: theta, alpha: alpha,
      beta: beta,   gamma: gamma, signalQuality: sq,
    );

    return BrainwaveSample(
      sessionId:     sessionId,
      timestampMs:   DateTime.now().millisecondsSinceEpoch,
      delta:         delta,
      theta:         theta,
      alpha:         alpha,
      beta:          beta,
      gamma:         gamma,
      signalQuality: sq,
      emotion:       result.emotion,
      confidence:    result.confidence,
    );
  }
}
