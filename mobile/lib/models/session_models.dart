class DashboardSummary {
  final String currentState;
  final double currentConfidence;
  final int focusTimeToday;
  final int totalTimeToday;
  final String topStateToday;
  final int sessionsToday;
  final LastSessionSummary? lastSession;

  const DashboardSummary({
    required this.currentState,
    required this.currentConfidence,
    required this.focusTimeToday,
    required this.totalTimeToday,
    required this.topStateToday,
    required this.sessionsToday,
    this.lastSession,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> j) => DashboardSummary(
    currentState: j['current_state'] as String? ?? 'neutral',
    currentConfidence: (j['current_confidence'] as num?)?.toDouble() ?? 0.0,
    focusTimeToday: j['focus_time_today'] as int? ?? 0,
    totalTimeToday: j['total_time_today'] as int? ?? 0,
    topStateToday: j['top_state_today'] as String? ?? 'neutral',
    sessionsToday: j['sessions_today'] as int? ?? 0,
    lastSession: j['last_session'] != null
        ? LastSessionSummary.fromJson(j['last_session'] as Map<String, dynamic>)
        : null,
  );
}

class LastSessionSummary {
  final String sessionId;
  final String? title;
  final int? durationSeconds;
  final String? dominantState;
  final double? averageConfidence;
  final String? endedAt;

  const LastSessionSummary({
    required this.sessionId,
    this.title,
    this.durationSeconds,
    this.dominantState,
    this.averageConfidence,
    this.endedAt,
  });

  factory LastSessionSummary.fromJson(Map<String, dynamic> j) => LastSessionSummary(
    sessionId: j['session_id'] as String,
    title: j['title'] as String?,
    durationSeconds: j['duration_seconds'] as int?,
    dominantState: j['dominant_state'] as String?,
    averageConfidence: (j['average_confidence'] as num?)?.toDouble(),
    endedAt: j['ended_at'] as String?,
  );
}

class SessionHistoryItem {
  final String sessionId;
  final String? title;
  final String startedAt;
  final String? endedAt;
  final int? durationSeconds;
  final String? dominantState;
  final double? averageConfidence;
  final int? focusTimeSeconds;

  const SessionHistoryItem({
    required this.sessionId,
    this.title,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.dominantState,
    this.averageConfidence,
    this.focusTimeSeconds,
  });

  factory SessionHistoryItem.fromJson(Map<String, dynamic> j) => SessionHistoryItem(
    sessionId: j['session_id'] as String,
    title: j['title'] as String?,
    startedAt: j['started_at'] as String,
    endedAt: j['ended_at'] as String?,
    durationSeconds: j['duration_seconds'] as int?,
    dominantState: j['dominant_state'] as String?,
    averageConfidence: (j['average_confidence'] as num?)?.toDouble(),
    focusTimeSeconds: j['focus_time_seconds'] as int?,
  );
}

class ChartPoint {
  final String label;
  final double value;
  const ChartPoint({required this.label, required this.value});

  factory ChartPoint.fromJson(Map<String, dynamic> j) => ChartPoint(
    label: j['label'] as String,
    value: (j['value'] as num).toDouble(),
  );
}

class StatsSummary {
  final int totalFocusTimeSeconds;
  final int totalSessionTimeSeconds;
  final int sessionsCount;
  final String dominantState;
  final double averageConfidence;
  final Map<String, double> stateBreakdown;
  final List<ChartPoint> chartData;
  final String focusTimeStr;

  const StatsSummary({
    required this.totalFocusTimeSeconds,
    required this.totalSessionTimeSeconds,
    required this.sessionsCount,
    required this.dominantState,
    required this.averageConfidence,
    required this.stateBreakdown,
    required this.chartData,
    required this.focusTimeStr,
  });

  factory StatsSummary.fromJson(Map<String, dynamic> j) => StatsSummary(
    totalFocusTimeSeconds: j['total_focus_time_seconds'] as int? ?? 0,
    totalSessionTimeSeconds: j['total_session_time_seconds'] as int? ?? 0,
    sessionsCount: j['sessions_count'] as int? ?? 0,
    dominantState: j['dominant_state'] as String? ?? 'neutral',
    averageConfidence: (j['average_confidence'] as num?)?.toDouble() ?? 0.0,
    stateBreakdown: (j['state_breakdown'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
        {},
    chartData: (j['chart_data'] as List<dynamic>?)
            ?.map((e) => ChartPoint.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    focusTimeStr: j['focus_time_str'] as String? ?? '0m',
  );
}
