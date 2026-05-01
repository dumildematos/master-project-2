import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around SharedPreferences — mirrors runtimeConfig.ts.
class StorageService {
  static const _keyUrl = 'sentioApiUrl';
  static const _defaultUrl = 'http://192.168.1.180:8000';
  static const _wsPath = '/ws/brain-stream';

  static String _trim(String v) => v.replaceAll(RegExp(r'/+$'), '');

  static Future<String> getApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return _trim(prefs.getString(_keyUrl) ?? _defaultUrl);
  }

  static Future<void> saveApiUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUrl, _trim(url.trim()));
  }

  static Future<String> resolveApiBaseUrl() => getApiUrl();

  static Future<String> resolveBrainStreamUrl() async {
    final base = await getApiUrl();
    final ws = base
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '${_trim(ws)}$_wsPath';
  }
}
