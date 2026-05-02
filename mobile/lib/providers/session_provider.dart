import 'package:flutter/foundation.dart';

import '../models/session_led_pattern.dart';
import '../models/session_models.dart';
import '../services/sentio_api.dart' as api;

class SessionProvider extends ChangeNotifier {
  DashboardSummary? _dashboardSummary;
  List<SessionHistoryItem> _history = [];
  StatsSummary? _statsSummary;
  String? _activeSessionId;
  DateTime? _sessionStartedAt;
  SessionLedPattern? _latestPattern;
  bool _isLoading = false;
  String? _error;

  DashboardSummary? get dashboardSummary => _dashboardSummary;
  List<SessionHistoryItem> get history => _history;
  StatsSummary? get statsSummary => _statsSummary;
  String? get activeSessionId => _activeSessionId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasActiveSession => _activeSessionId != null;
  SessionLedPattern? get latestPattern => _latestPattern;

  int get sessionDuration {
    final start = _sessionStartedAt;
    if (start == null) return 0;
    return DateTime.now().difference(start).inSeconds;
  }

  Future<void> fetchDashboardSummary() async {
    try {
      final data = await api.getDashboardSummary();
      _dashboardSummary = DashboardSummary.fromJson(data);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> fetchHistory(String range) async {
    _isLoading = true;
    notifyListeners();
    try {
      final list = await api.getSessionHistory(range);
      _history = list
          .map((e) => SessionHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchStats(String range) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await api.getStats(range);
      _statsSummary = StatsSummary.fromJson(data);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<String> startSession(String? title) async {
    final data = await api.startSessionRecord(title);
    _activeSessionId = data['session_id'] as String;
    _sessionStartedAt = DateTime.now();
    notifyListeners();
    return _activeSessionId!;
  }

  Future<void> recoverActiveSession() async {
    try {
      final info = await api.getActiveSession();
      if (!info.active || info.sessionId == null) {
        if (_activeSessionId != null) {
          _activeSessionId = null;
          _sessionStartedAt = null;
          _latestPattern = null;
          notifyListeners();
        }
        return;
      }
      final changed = _activeSessionId != info.sessionId;
      _activeSessionId = info.sessionId;
      if (info.startedAt != null) {
        _sessionStartedAt = DateTime.tryParse(info.startedAt!);
      }
      _latestPattern = info.latestPattern;
      if (changed) notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchLatestPattern() async {
    final sid = _activeSessionId;
    if (sid == null) return;
    try {
      _latestPattern = await api.getSessionLatestPattern(sid);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> endSession() async {
    final sid = _activeSessionId;
    if (sid == null) return;
    try {
      await api.endSessionRecord(sid);
    } finally {
      _activeSessionId = null;
      _sessionStartedAt = null;
      _latestPattern = null;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> stopSession() async {
    final sid = _activeSessionId;
    if (sid == null) throw Exception('No active session to stop');
    try {
      final data = await api.stopSessionRecord(sid);
      _activeSessionId = null;
      _sessionStartedAt = null;
      _latestPattern = null;
      notifyListeners();
      return data;
    } catch (e) {
      _activeSessionId = null;
      _sessionStartedAt = null;
      _latestPattern = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteSession(String sessionId) async {
    await api.deleteSessionRecord(sessionId);
    _history.removeWhere((s) => s.sessionId == sessionId);
    notifyListeners();
  }
}
