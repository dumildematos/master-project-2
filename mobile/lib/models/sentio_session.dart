class SentioSession {
  final String   id;
  final String   title;
  final DateTime startTime;
  final DateTime? endTime;
  final int      durationSeconds;
  final int      score;         // 0–100
  final String   topEmotion;
  final bool     isCompleted;

  const SentioSession({
    required this.id,
    required this.title,
    required this.startTime,
    this.endTime,
    required this.durationSeconds,
    required this.score,
    required this.topEmotion,
    required this.isCompleted,
  });

  factory SentioSession.fromMap(Map<String, dynamic> map) => SentioSession(
    id:              map['id'] as String,
    title:           map['title'] as String,
    startTime:       DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int),
    endTime:         map['end_time'] != null
                       ? DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int)
                       : null,
    durationSeconds: map['duration_seconds'] as int,
    score:           map['score'] as int,
    topEmotion:      map['top_emotion'] as String,
    isCompleted:     (map['is_completed'] as int) == 1,
  );

  Map<String, dynamic> toMap() => {
    'id':               id,
    'title':            title,
    'start_time':       startTime.millisecondsSinceEpoch,
    'end_time':         endTime?.millisecondsSinceEpoch,
    'duration_seconds': durationSeconds,
    'score':            score,
    'top_emotion':      topEmotion,
    'is_completed':     isCompleted ? 1 : 0,
  };

  SentioSession copyWith({
    String?   id,
    String?   title,
    DateTime? startTime,
    DateTime? endTime,
    int?      durationSeconds,
    int?      score,
    String?   topEmotion,
    bool?     isCompleted,
  }) => SentioSession(
    id:              id              ?? this.id,
    title:           title           ?? this.title,
    startTime:       startTime       ?? this.startTime,
    endTime:         endTime         ?? this.endTime,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    score:           score           ?? this.score,
    topEmotion:      topEmotion      ?? this.topEmotion,
    isCompleted:     isCompleted     ?? this.isCompleted,
  );
}

class BrainwaveSample {
  final String sessionId;
  final int    timestampMs;
  final double delta;
  final double theta;
  final double alpha;
  final double beta;
  final double gamma;
  final double signalQuality;
  final String emotion;
  final double confidence;

  const BrainwaveSample({
    required this.sessionId,
    required this.timestampMs,
    required this.delta,
    required this.theta,
    required this.alpha,
    required this.beta,
    required this.gamma,
    required this.signalQuality,
    required this.emotion,
    required this.confidence,
  });

  factory BrainwaveSample.fromMap(Map<String, dynamic> map) => BrainwaveSample(
    sessionId:     map['session_id'] as String,
    timestampMs:   map['timestamp_ms'] as int,
    delta:         (map['delta'] as num).toDouble(),
    theta:         (map['theta'] as num).toDouble(),
    alpha:         (map['alpha'] as num).toDouble(),
    beta:          (map['beta'] as num).toDouble(),
    gamma:         (map['gamma'] as num).toDouble(),
    signalQuality: (map['signal_quality'] as num).toDouble(),
    emotion:       map['emotion'] as String,
    confidence:    (map['confidence'] as num).toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'session_id':     sessionId,
    'timestamp_ms':   timestampMs,
    'delta':          delta,
    'theta':          theta,
    'alpha':          alpha,
    'beta':           beta,
    'gamma':          gamma,
    'signal_quality': signalQuality,
    'emotion':        emotion,
    'confidence':     confidence,
  };
}
