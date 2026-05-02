class EmotionResult {
  final String emotion;
  final double confidence; // 0–100
  const EmotionResult(this.emotion, this.confidence);
}

class EmotionClassifier {
  const EmotionClassifier._();

  static EmotionResult classify({
    required double delta,
    required double theta,
    required double alpha,
    required double beta,
    required double gamma,
    required double signalQuality,
  }) {
    if (signalQuality < 0.3) return const EmotionResult('neutral', 0);

    final total = delta + theta + alpha + beta + gamma;
    if (total < 0.01) return const EmotionResult('neutral', 0);

    final a = alpha / total;
    final b = beta  / total;
    final t = theta / total;
    final g = gamma / total;

    // Rule-based heuristics from band-power ratios
    if (b > 0.40 && a < 0.25) {
      // High beta, low alpha → stressed
      return EmotionResult('stressed', (b * 220).clamp(0, 100));
    } else if (b > 0.30 && a > 0.20) {
      // High beta + moderate alpha → focused
      return EmotionResult('focused', ((b + a) * 130).clamp(0, 100));
    } else if (a > 0.40) {
      // Dominant alpha → calm
      return EmotionResult('calm', (a * 200).clamp(0, 100));
    } else if (t > 0.35 || (a > 0.25 && b < 0.25)) {
      // High theta or mild alpha with low beta → relaxed
      return EmotionResult('relaxed', ((t + a) * 160).clamp(0, 100));
    } else if (g > 0.18) {
      // Elevated gamma → excited
      return EmotionResult('excited', (g * 350).clamp(0, 100));
    } else {
      return const EmotionResult('neutral', 50);
    }
  }
}
