class SessionLedPattern {
  final String emotion;
  final int confidence;
  final String mode;
  final String modeName;
  final int brightness;
  final int speed;
  final String primaryColor;
  final String secondaryColor;
  final List<List<int>> grid;
  final String updatedAt;

  const SessionLedPattern({
    required this.emotion,
    required this.confidence,
    required this.mode,
    required this.modeName,
    required this.brightness,
    required this.speed,
    required this.primaryColor,
    required this.secondaryColor,
    required this.grid,
    required this.updatedAt,
  });

  factory SessionLedPattern.fromJson(Map<String, dynamic> j) {
    final rawGrid = j['grid'] as List<dynamic>;
    final grid = rawGrid
        .map((row) => (row as List<dynamic>).map((v) => v as int).toList())
        .toList();
    return SessionLedPattern(
      emotion:        j['emotion']         as String,
      confidence:     j['confidence']      as int,
      mode:           j['mode']            as String,
      modeName:       j['mode_name']       as String,
      brightness:     j['brightness']      as int,
      speed:          j['speed']           as int,
      primaryColor:   j['primary_color']   as String,
      secondaryColor: j['secondary_color'] as String,
      grid:           grid,
      updatedAt:      j['updated_at']      as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'mode':       mode,
    'brightness': brightness,
    'speed':      speed,
    'colors':     [primaryColor, secondaryColor],
    'pattern':    grid,
  };
}

class ActiveSessionInfo {
  final bool active;
  final String? sessionId;
  final String? startedAt;
  final int? durationSeconds;
  final String? currentState;
  final double? currentConfidence;
  final SessionLedPattern? latestPattern;

  const ActiveSessionInfo({
    required this.active,
    this.sessionId,
    this.startedAt,
    this.durationSeconds,
    this.currentState,
    this.currentConfidence,
    this.latestPattern,
  });

  factory ActiveSessionInfo.fromJson(Map<String, dynamic> j) {
    final patternJson = j['latest_pattern'] as Map<String, dynamic>?;
    return ActiveSessionInfo(
      active:            j['active']             as bool,
      sessionId:         j['session_id']         as String?,
      startedAt:         j['started_at']         as String?,
      durationSeconds:   j['duration_seconds']   as int?,
      currentState:      j['current_state']      as String?,
      currentConfidence: (j['current_confidence'] as num?)?.toDouble(),
      latestPattern:     patternJson != null
          ? SessionLedPattern.fromJson(patternJson)
          : null,
    );
  }
}
