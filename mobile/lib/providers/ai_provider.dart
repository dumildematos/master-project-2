import 'package:flutter/foundation.dart';

import '../models/ai_models.dart';
import '../services/sentio_api.dart' as api;

class AiProvider extends ChangeNotifier {
  AiStatus? _status;
  bool _isSubmitting = false;
  bool _isTraining = false;
  String? _error;

  // Last feedback label submitted in this session (to show confirmation)
  String? _lastFeedbackLabel;

  AiStatus? get status => _status;
  bool get isSubmitting => _isSubmitting;
  bool get isTraining => _isTraining;
  String? get error => _error;
  String? get lastFeedbackLabel => _lastFeedbackLabel;

  Future<void> fetchStatus() async {
    try {
      final data = await api.getAiStatus();
      _status = AiStatus.fromJson(data);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  // Submit user feedback: the AI said X but the correct emotion was [label].
  // Optionally pass current band powers so they are stored with the label.
  Future<bool> submitFeedback({
    required String label,
    String? sessionId,
    double? alpha,
    double? beta,
    double? theta,
    double? gamma,
    double? delta,
  }) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      await api.submitEmotionLabel(
        label:     label,
        sessionId: sessionId,
        alpha:     alpha,
        beta:      beta,
        theta:     theta,
        gamma:     gamma,
        delta:     delta,
      );
      _lastFeedbackLabel = label;
      // Refresh status so the label count updates
      await fetchStatus();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> triggerTraining() async {
    _isTraining = true;
    _error = null;
    notifyListeners();

    try {
      await api.triggerModelTraining();
      await fetchStatus();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isTraining = false;
      notifyListeners();
    }
  }

  Future<CalibrationResult?> submitCalibration(
      List<CalibrationStep> steps) async {
    try {
      final data = await api.submitCalibration(
        steps.map((s) => s.toJson()).toList(),
      );
      await fetchStatus();
      return CalibrationResult.fromJson(data);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  void clearFeedback() {
    _lastFeedbackLabel = null;
    notifyListeners();
  }
}
