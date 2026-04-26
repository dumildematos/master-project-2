/// Live state broadcast by the backend WebSocket.
class SentioVitals {
  final double? heartBpm;
  final double? heartConfidence;
  final double? respirationRpm;
  final double? respirationConfidence;

  const SentioVitals({
    this.heartBpm,
    this.heartConfidence,
    this.respirationRpm,
    this.respirationConfidence,
  });
}

class AiPattern {
  final String patternType;
  final String primary;
  final String secondary;
  final String accent;
  final String shadow;
  final double speed;
  final double complexity;
  final double intensity;

  const AiPattern({
    required this.patternType,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.shadow,
    required this.speed,
    required this.complexity,
    required this.intensity,
  });
}

class SentioState {
  final double alpha, beta, theta, gamma, delta;
  final String emotion;
  final double confidence;          // 0–100 %
  final bool isUncertain;
  final double? mindfulness;
  final double? restfulness;
  final double signalQuality;
  final SentioVitals vitals;
  final String? aiGuidance;
  final AiPattern? aiPattern;

  const SentioState({
    required this.alpha,
    required this.beta,
    required this.theta,
    required this.gamma,
    required this.delta,
    required this.emotion,
    required this.confidence,
    required this.isUncertain,
    this.mindfulness,
    this.restfulness,
    required this.signalQuality,
    required this.vitals,
    this.aiGuidance,
    this.aiPattern,
  });

  static const SentioState initial = SentioState(
    alpha: 0, beta: 0, theta: 0, gamma: 0, delta: 0,
    emotion: 'neutral', confidence: 0, isUncertain: true,
    signalQuality: 0, vitals: SentioVitals(),
  );
}

class BandHistory {
  final double alpha, beta, theta, gamma, delta;
  final int timestamp;

  const BandHistory({
    required this.alpha, required this.beta,
    required this.theta, required this.gamma,
    required this.delta, required this.timestamp,
  });
}

class EmotionHistoryEntry {
  final String emotion;
  final double confidence;
  final int timestamp;

  const EmotionHistoryEntry({
    required this.emotion,
    required this.confidence,
    required this.timestamp,
  });
}
