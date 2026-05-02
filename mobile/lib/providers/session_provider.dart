import 'package:flutter/foundation.dart';

import '../models/session_models.dart';
import '../services/sentio_api.dart' as api;

class SessionProvider extends ChangeNotifier {
  DashboardSummary? _dashboardSummary;
  List<SessionHistoryItem> _history = [];
  StatsSummary? _statsSummary;
  String? _activeSessionId;
  bool _isLoading = false;
  String? _error;

  DashboardSummary? get dashboardSummary => _dashboardSummary;
  List<SessionHistoryItem> get history => _history;
  StatsSummary? get statsSummary => _statsSummary;
  String? get activeSessionId => _activeSessionId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasActiveSession => _activeSessionId != null;

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
    notifyListeners();
    return _activeSessionId!;
  }

  Future<void> endSession() async {
    final sid = _activeSessionId;
    if (sid == null) return;
    try {
      await api.endSessionRecord(sid);
    } finally {
      _activeSessionId = null;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> stopSession() async {
    final sid = _activeSessionId;
    if (sid == null) throw Exception('No active session to stop');
    try {
      final data = await api.stopSessionRecord(sid);
      _activeSessionId = null;
      notifyListeners();
      return data;
    } catch (e) {
      _activeSessionId = null;
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
