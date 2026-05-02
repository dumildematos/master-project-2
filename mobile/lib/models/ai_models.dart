// Data models for the AI emotion detection pipeline.
// These mirror the Pydantic schemas in backend/api/ai_router.py.

class EmotionPrediction {
  final String emotion;
  final double confidence;
  final Map<String, double> scores;
  final String modelUsed; // "ai_user" | "ai_global" | "rule_based"

  const EmotionPrediction({
    required this.emotion,
    required this.confidence,
    required this.scores,
    required this.modelUsed,
  });

  factory EmotionPrediction.fromJson(Map<String, dynamic> j) =>
      EmotionPrediction(
        emotion:    j['emotion']    as String,
        confidence: (j['confidence'] as num).toDouble(),
        scores:     (j['scores'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ),
        modelUsed: j['model_used'] as String? ?? 'rule_based',
      );

  /// Dominant alternative emotion (second-highest score).
  String? get secondEmotion {
    if (scores.isEmpty) return null;
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.length > 1 ? sorted[1].key : null;
  }
}


class AiStatus {
  final bool hasUserModel;
  final bool hasGlobalModel;
  final double? userModelAccuracy;
  final double? globalModelAccuracy;
  final int nUserLabels;
  final int labelsUntilTrain;

  const AiStatus({
    required this.hasUserModel,
    required this.hasGlobalModel,
    this.userModelAccuracy,
    this.globalModelAccuracy,
    required this.nUserLabels,
    required this.labelsUntilTrain,
  });

  factory AiStatus.fromJson(Map<String, dynamic> j) => AiStatus(
        hasUserModel:         j['has_user_model']   as bool? ?? false,
        hasGlobalModel:       j['has_global_model'] as bool? ?? false,
        userModelAccuracy:    (j['user_model_accuracy']   as num?)?.toDouble(),
        globalModelAccuracy:  (j['global_model_accuracy'] as num?)?.toDouble(),
        nUserLabels:          j['n_user_labels']          as int? ?? 0,
        labelsUntilTrain:     j['labels_until_train']     as int? ?? 50,
      );

  String get modelLabel {
    if (hasUserModel) return 'Personalized AI';
    if (hasGlobalModel) return 'Global AI';
    return 'Rule-based';
  }
}


class CalibrationStep {
  final String step;   // "neutral" | "focus" | "relax"
  final double alpha;
  final double beta;
  final double theta;
  final double gamma;
  final double delta;
  final int durationSeconds;

  const CalibrationStep({
    required this.step,
    required this.alpha,
    required this.beta,
    required this.theta,
    required this.gamma,
    required this.delta,
    required this.durationSeconds,
  });

  Map<String, dynamic> toJson() => {
        'step':             step,
        'alpha':            alpha,
        'beta':             beta,
        'theta':            theta,
        'gamma':            gamma,
        'delta':            delta,
        'duration_seconds': durationSeconds,
      };
}


class CalibrationResult {
  final double alphaMean;
  final double betaMean;
  final double thetaMean;
  final String message;

  const CalibrationResult({
    required this.alphaMean,
    required this.betaMean,
    required this.thetaMean,
    required this.message,
  });

  factory CalibrationResult.fromJson(Map<String, dynamic> j) =>
      CalibrationResult(
        alphaMean: (j['alpha_mean'] as num).toDouble(),
        betaMean:  (j['beta_mean']  as num).toDouble(),
        thetaMean: (j['theta_mean'] as num).toDouble(),
        message:   j['message']    as String,
      );
}
