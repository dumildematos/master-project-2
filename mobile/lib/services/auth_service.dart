import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import 'storage_service.dart';

// ---------------------------------------------------------------------------
// Secure token storage
// ---------------------------------------------------------------------------
const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

const _kTokenKey = 'sentio_jwt';
const _kLegacyUserKey = 'sentio_user'; // old secure-storage user key

Future<void> saveAuthToken(String token) =>
    _storage.write(key: _kTokenKey, value: token);

Future<String?> getAuthToken() => _storage.read(key: _kTokenKey);

Future<void> clearAuth() async {
  await _storage.delete(key: _kTokenKey);
  await _storage.delete(key: _kLegacyUserKey);
  await deleteUser();
}

// ---------------------------------------------------------------------------
// User profile cache (SharedPreferences — non-sensitive)
// ---------------------------------------------------------------------------
const _kUserPrefKey = 'sentio_cached_user';

Future<void> saveUser(AppUser user) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kUserPrefKey, jsonEncode(user.toJson()));
}

Future<AppUser?> loadSavedUser() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUserPrefKey);
    if (raw == null) return null;
    return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

Future<void> deleteUser() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kUserPrefKey);
}

// ---------------------------------------------------------------------------
// Google Sign-In instance
// ---------------------------------------------------------------------------
// serverClientId tells google_sign_in to request an ID token signed
// for our backend (web client ID). The resulting idToken is sent to
// POST /api/auth/google.
final _googleSignIn = GoogleSignIn(
  serverClientId:
      '826283652661-rgafrpmdt2u37gqg6l4rtqbsdaq59egm.apps.googleusercontent.com',
  scopes: ['email', 'profile'],
);

// ---------------------------------------------------------------------------
// Auth Service
// ---------------------------------------------------------------------------
class AuthService {
  // ── Email / password ──────────────────────────────────────────────────────

  static Future<AppUser> register({
    required String email,
    required String password,
    String? name,
  }) async {
    final res = await _post('/api/auth/register', {
      'email': email,
      'password': password,
      if (name != null) 'name': name,
    });
    return _handleAuthResponse(res);
  }

  static Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final res = await _post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    return _handleAuthResponse(res);
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────

  static Future<AppUser?> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null; // user cancelled

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        throw Exception(
          'Google Sign-In did not return an ID token. '
          'Ensure the server client ID is registered in the Google Console '
          'with the correct SHA-1 fingerprint for this app.',
        );
      }

      final res = await _post('/api/auth/google', {'id_token': idToken});
      return _handleAuthResponse(res);
    } catch (e) {
      debugPrint('[AuthService] Google sign-in error: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await clearAuth();
  }

  // ── Token refresh ─────────────────────────────────────────────────────────

  static Future<AppUser?> refreshIfNeeded() async {
    final token = await getAuthToken();
    if (token == null) return null;
    try {
      final base = await StorageService.getApiUrl();
      final res = await http.post(
        Uri.parse('$base/api/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        return _handleAuthResponse(res);
      }
    } catch (_) {}
    return null;
  }

  // ── Current user (from backend) ───────────────────────────────────────────

  static Future<AppUser?> fetchMe() async {
    final token = await getAuthToken();
    if (token == null) return null;
    try {
      final base = await StorageService.getApiUrl();
      final res = await http.get(
        Uri.parse('$base/api/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final user =
            AppUser.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
        await saveUser(user);
        return user;
      }
    } catch (_) {}
    return null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Future<http.Response> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final base = await StorageService.getApiUrl();
    return http.post(
      Uri.parse('$base$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }

  static Future<AppUser> _handleAuthResponse(http.Response res) async {
    if (res.statusCode != 200 && res.statusCode != 201) {
      final detail =
          (jsonDecode(res.body) as Map?)?['detail'] ?? res.body;
      throw Exception(detail);
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final token = json['access_token'] as String;
    // Merge access_token into the user json so AppUser.fromJson can store it
    final userJson =
        Map<String, dynamic>.from(json['user'] as Map<String, dynamic>)
          ..['access_token'] = token;
    final user = AppUser.fromJson(userJson);
    await saveAuthToken(token);
    await saveUser(user);
    return user;
  }
}
