import 'package:flutter/foundation.dart';
import '../models/generated_led_pattern.dart';
import '../services/sentio_api.dart' as api;

class LedProvider extends ChangeNotifier {
  bool _isGeneratingAiPattern = false;
  GeneratedLedPattern? _generatedPattern;
  String? _aiPatternError;

  bool get isGeneratingAiPattern => _isGeneratingAiPattern;
  GeneratedLedPattern? get generatedPattern => _generatedPattern;
  String? get aiPatternError => _aiPatternError;

  Future<void> generateAiPattern(String prompt, int brightness, int speed) async {
    _isGeneratingAiPattern = true;
    _aiPatternError = null;
    notifyListeners();
    try {
      _generatedPattern = await api.generateLedPattern(
          prompt: prompt, brightness: brightness, speed: speed);
      _aiPatternError = null;
    } catch (e) {
      _aiPatternError = e.toString();
      _generatedPattern = null;
    } finally {
      _isGeneratingAiPattern = false;
      notifyListeners();
    }
  }

  void applyGeneratedPattern(GeneratedLedPattern pattern) {
    _generatedPattern = pattern;
    notifyListeners();
  }

  void clearPattern() {
    _generatedPattern = null;
    _aiPatternError = null;
    notifyListeners();
  }
}
