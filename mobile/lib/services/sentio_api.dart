import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import 'auth_service.dart' show getAuthToken;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------
class SessionStatus {
  final String? sessionId;
  final String state;
  final int emotionHistoryLength;

  const SessionStatus({
    this.sessionId,
    required this.state,
    required this.emotionHistoryLength,
  });

  factory SessionStatus.fromJson(Map<String, dynamic> j) => SessionStatus(
    sessionId: j['session_id'] as String?,
    state: j['state'] as String? ?? 'idle',
    emotionHistoryLength: j['emotion_history_length'] as int? ?? 0,
  );
}

class SessionConfig {
  final String patternType;
  final double signalSensitivity;
  final double emotionSmoothing;
  final double noiseControl;
  final String? deviceSource;

  const SessionConfig({
    required this.patternType,
    required this.signalSensitivity,
    required this.emotionSmoothing,
    this.noiseControl = 1.0,
    this.deviceSource,
  });

  Map<String, dynamic> toJson() => {
    'pattern_type':       patternType,
    'signal_sensitivity': signalSensitivity,
    'emotion_smoothing':  emotionSmoothing,
    'noise_control':      noiseControl,
    if (deviceSource != null) 'device_source': deviceSource,
  };
}

// ---------------------------------------------------------------------------
// Emotion presets (mirrors web frontend)
// ---------------------------------------------------------------------------
const Map<String, Map<String, double>> kEmotionPresets = {
  'calm':     {
    'alpha': 0.68, 'beta': 0.18, 'theta': 0.16,
    'gamma': 0.06, 'delta': 0.05, 'confidence': 0.84,
  },
  'focused':  {
    'alpha': 0.32, 'beta': 0.72, 'theta': 0.10,
    'gamma': 0.14, 'delta': 0.03, 'confidence': 0.91,
  },
  'stressed': {
    'alpha': 0.22, 'beta': 0.88, 'theta': 0.08,
    'gamma': 0.18, 'delta': 0.04, 'confidence': 0.76,
  },
  'relaxed':  {
    'alpha': 0.75, 'beta': 0.12, 'theta': 0.45,
    'gamma': 0.05, 'delta': 0.08, 'confidence': 0.88,
  },
  'excited':  {
    'alpha': 0.40, 'beta': 0.65, 'theta': 0.12,
    'gamma': 0.32, 'delta': 0.04, 'confidence': 0.87,
  },
};

// ---------------------------------------------------------------------------
// API helper — attaches JWT when available
// ---------------------------------------------------------------------------
Future<http.Response> _api(String path, {
  String method = 'GET',
  Map<String, dynamic>? body,
}) async {
  final base  = await StorageService.resolveApiBaseUrl();
  final uri   = Uri.parse('$base/api$path');
  final token = await getAuthToken();   // from auth_service.dart
  final headers = <String, String>{
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
  return switch (method) {
    'POST'   => http.post(uri,   headers: headers, body: jsonEncode(body ?? {})),
    'PATCH'  => http.patch(uri,  headers: headers, body: jsonEncode(body ?? {})),
    'DELETE' => http.delete(uri, headers: headers),
    _        => http.get(uri,    headers: headers),
  };
}

Future<SessionStatus> getSessionStatus() async {
  final res = await _api('/session/status');
  if (res.statusCode != 200) throw Exception('Session status ${res.statusCode}');
  return SessionStatus.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
}

Future<void> startSession(SessionConfig config) async {
  final res = await _api('/session/start', method: 'POST', body: config.toJson());
  if (res.statusCode != 200) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final detail = body['detail'];
    throw Exception(detail is String ? detail : 'Start failed (${res.statusCode})');
  }
}

Future<void> stopSession() async {
  final res = await _api('/session/stop', method: 'POST');
  if (res.statusCode != 200) throw Exception('Stop session ${res.statusCode}');
}

Future<void> sendManualOverride(String emotion) async {
  final bands = kEmotionPresets[emotion];
  if (bands == null) throw Exception('Unknown emotion: $emotion');
  final res = await _api('/manual/override', method: 'POST', body: {
    'emotion': emotion, ...bands,
  });
  if (res.statusCode != 200) throw Exception('Override ${res.statusCode}');
}

Future<void> postMobileBands(Map<String, double> payload) async {
  final base = await StorageService.resolveApiBaseUrl();
  await http.post(
    Uri.parse('$base/api/eeg/mobile-bands'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(payload),
  ).catchError((_) {}); // Non-fatal — keep buffering locally
}

/// Override the Arduino pattern type for the active session.
/// Pass null to restore automatic AI/emotion-based selection.
Future<void> selectPattern(String? patternType) async {
  final res = await _api('/pattern/select', method: 'POST', body: {
    'pattern_type': patternType,
  });
  if (res.statusCode != 200) {
    throw Exception('selectPattern failed (${res.statusCode})');
  }
}
