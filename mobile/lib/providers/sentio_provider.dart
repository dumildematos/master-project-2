/// SentioProvider
/// ---------------
/// ChangeNotifier that owns a single WebSocket connection to the backend
/// /ws/brain-stream endpoint, parses incoming JSON frames, and maintains
/// rolling EEG band history + emotion history.
///
/// Auto-reconnects with a 2 s back-off on close/error.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/sentio_state.dart';
import '../services/storage_service.dart';

const int    _kUncertainThreshold  = 42; // % — mirrors BrainContext
const int    _kEmotionHistoryMax   = 20;
const Duration _kRetryDelay        = Duration(seconds: 2);

class SentioProvider extends ChangeNotifier {
  SentioState _data  = SentioState.initial;
  bool _connected    = false;
  bool _hasSignal    = false;
  List<BandHistory>        _history        = [];
  List<EmotionHistoryEntry> _emotionHistory = [];

  SentioState               get data           => _data;
  bool                      get connected      => _connected;
  bool                      get hasSignal      => _hasSignal;
  List<BandHistory>         get history        => List.unmodifiable(_history);
  List<EmotionHistoryEntry> get emotionHistory => List.unmodifiable(_emotionHistory);

  // Internal
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _retryTimer;
  bool _disposed = false;

  SentioProvider() {
    _init();
  }

  Future<void> _init() async {
    final url = await StorageService.resolveBrainStreamUrl();
    _connect(url);
  }

  /// Force-reconnect (e.g. after the user saves a new backend URL).
  Future<void> reconnect() async {
    _retryTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    await _init();
  }

  void _connect(String url) {
    if (_disposed) return;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _sub = _channel!.stream.listen(
        _onMessage,
        onDone:  () => _scheduleRetry(url),
        onError: (_) => _scheduleRetry(url),
      );
      _connected = true;
      notifyListeners();
    } catch (_) {
      _scheduleRetry(url);
    }
  }

  void _scheduleRetry(String url) {
    if (_disposed) return;
    _connected = false;
    notifyListeners();
    _retryTimer = Timer(_kRetryDelay, () => _connect(url));
  }

  void _onMessage(dynamic raw) {
    if (_disposed) return;
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      if (json['type'] == 'heartbeat' || json['status'] == 'waiting') return;

      final state = _parseFrame(json);
      _data       = state;
      _hasSignal  = true;

      final now = DateTime.now().millisecondsSinceEpoch;
      _history = [
        ..._history.length >= 100 ? _history.sublist(1) : _history,
        BandHistory(
          alpha: state.alpha, beta: state.beta, theta: state.theta,
          gamma: state.gamma, delta: state.delta, timestamp: now,
        ),
      ];

      final last = _emotionHistory.isNotEmpty ? _emotionHistory.last : null;
      if (last == null ||
          last.emotion != state.emotion ||
          now - last.timestamp >= 2000) {
        final history = List.of(_emotionHistory);
        if (history.length >= _kEmotionHistoryMax) history.removeAt(0);
        history.add(EmotionHistoryEntry(
          emotion: state.emotion, confidence: state.confidence, timestamp: now,
        ));
        _emotionHistory = history;
      }

      notifyListeners();
    } catch (_) { /* malformed frame — skip */ }
  }

  SentioState _parseFrame(Map<String, dynamic> j) {
    double n(String k, [double fb = 0]) {
      final v = j[k];
      return v is num ? v.toDouble() : fb;
    }
    String s(String k) {
      final v = j[k];
      if (v is! String || v.trim().isEmpty) return 'neutral';
      final t = v.trim().toLowerCase();
      return '${t[0].toUpperCase()}${t.substring(1)}';
    }

    final rawConf   = n('confidence');
    final conf      = rawConf <= 1 ? rawConf * 100 : rawConf;

    // AI pattern
    AiPattern? aiPattern;
    final ap = j['ai_pattern'];
    if (ap is Map<String, dynamic> && ap['pattern_type'] is String) {
      aiPattern = AiPattern(
        patternType: ap['pattern_type'] as String,
        primary:     ap['primary']     as String? ?? '#29d9c8',
        secondary:   ap['secondary']   as String? ?? '#6b7fa3',
        accent:      ap['accent']      as String? ?? '#f5a623',
        shadow:      ap['shadow']      as String? ?? '#080c10',
        speed:       (ap['speed']       as num?)?.toDouble() ?? 0.5,
        complexity:  (ap['complexity']  as num?)?.toDouble() ?? 0.5,
        intensity:   (ap['intensity']   as num?)?.toDouble() ?? 0.5,
      );
    }

    return SentioState(
      alpha: n('alpha'), beta: n('beta'), theta: n('theta'),
      gamma: n('gamma'), delta: n('delta'),
      emotion:       s('emotion'),
      confidence:    conf,
      isUncertain:   conf < _kUncertainThreshold,
      mindfulness:   j['mindfulness'] is num ? (j['mindfulness'] as num).toDouble() : null,
      restfulness:   j['restfulness'] is num ? (j['restfulness'] as num).toDouble() : null,
      signalQuality: j['signal_quality'] is num
          ? (j['signal_quality'] as num).toDouble()
          : (j['signal'] is num ? (j['signal'] as num).toDouble() * 100 : 0),
      vitals: SentioVitals(
        heartBpm:              j['heart_bpm']              is num ? (j['heart_bpm'] as num).toDouble()              : null,
        heartConfidence:       j['heart_confidence']       is num ? (j['heart_confidence'] as num).toDouble()       : null,
        respirationRpm:        j['respiration_rpm']        is num ? (j['respiration_rpm'] as num).toDouble()        : null,
        respirationConfidence: j['respiration_confidence'] is num ? (j['respiration_confidence'] as num).toDouble() : null,
      ),
      aiGuidance: j['ai_guidance'] is String && (j['ai_guidance'] as String).isNotEmpty
          ? j['ai_guidance'] as String
          : null,
      aiPattern: aiPattern,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
