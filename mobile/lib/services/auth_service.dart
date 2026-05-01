import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

// ---------------------------------------------------------------------------
// Secure token storage
// ---------------------------------------------------------------------------
const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

const _kTokenKey    = 'sentio_jwt';
const _kUserKey     = 'sentio_user';

Future<void> saveAuthToken(String token) =>
    _storage.write(key: _kTokenKey, value: token);

Future<String?> getAuthToken() => _storage.read(key: _kTokenKey);

Future<void> clearAuth() async {
  await _storage.delete(key: _kTokenKey);
  await _storage.delete(key: _kUserKey);
}

// ---------------------------------------------------------------------------
// Cached user model
// ---------------------------------------------------------------------------
class AuthUser {
  final String  id;
  final String  email;
  final String? name;
  final String? avatarUrl;
  final String  provider;

  const AuthUser({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
    required this.provider,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id:        j['id']         as String,
    email:     j['email']      as String,
    name:      j['name']       as String?,
    avatarUrl: j['avatar_url'] as String?,
    provider:  j['provider']   as String? ?? 'email',
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'email': email, 'name': name,
    'avatar_url': avatarUrl, 'provider': provider,
  };
}

// ---------------------------------------------------------------------------
// Google Sign-In instance
// ---------------------------------------------------------------------------
// serverClientId tells google_sign_in to request an ID token signed
// for our backend (web client ID).  The resulting idToken is what we
// send to POST /api/auth/google.
final _googleSignIn = GoogleSignIn(
  serverClientId: '826283652661-rgafrpmdt2u37gqg6l4rtqbsdaq59egm.apps.googleusercontent.com',
  scopes: ['email', 'profile'],
);

// ---------------------------------------------------------------------------
// Auth Service
// ---------------------------------------------------------------------------
class AuthService {
  // ── Email / password ────────────────────────────────────────────────────

  static Future<AuthUser> register({
    required String email,
    required String password,
    String? name,
  }) async {
    final res = await _post('/api/auth/register', {
      'email': email, 'password': password, if (name != null) 'name': name,
    });
    return _handleAuthResponse(res);
  }

  static Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final res = await _post('/api/auth/login', {
      'email': email, 'password': password,
    });
    return _handleAuthResponse(res);
  }

  // ── Google Sign-In ───────────────────────────────────────────────────────

  static Future<AuthUser?> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;   // user cancelled

      final auth    = await account.authentication;
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
    await _googleSignIn.signOut();
    await clearAuth();
  }

  // ── Token refresh ────────────────────────────────────────────────────────

  static Future<AuthUser?> refreshIfNeeded() async {
    final token = await getAuthToken();
    if (token == null) return null;
    try {
      final base = await StorageService.getApiUrl();
      final res  = await http.post(
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

  // ── Current user (from backend) ──────────────────────────────────────────

  static Future<AuthUser?> fetchMe() async {
    final token = await getAuthToken();
    if (token == null) return null;
    try {
      final base = await StorageService.getApiUrl();
      final res  = await http.get(
        Uri.parse('$base/api/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        return AuthUser.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

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

  static Future<AuthUser> _handleAuthResponse(http.Response res) async {
    if (res.statusCode != 200 && res.statusCode != 201) {
      final detail = (jsonDecode(res.body) as Map?)?['detail'] ?? res.body;
      throw Exception(detail);
    }
    final json  = jsonDecode(res.body) as Map<String, dynamic>;
    final token = json['access_token'] as String;
    final user  = AuthUser.fromJson(json['user'] as Map<String, dynamic>);
    await saveAuthToken(token);
    return user;
  }
}
