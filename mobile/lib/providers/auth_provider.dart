import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _currentUser;
  bool _isLoading = true;
  String? _error;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get error => _error;

  // ── Startup session check ─────────────────────────────────────────────────

  Future<void> loadSession() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await getAuthToken();
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Fast path: serve from local cache immediately, then refresh silently.
      final cached = await loadSavedUser();
      if (cached != null) {
        _currentUser = cached;
        _isLoading = false;
        notifyListeners();
        _refreshSilently();
        return;
      }

      // No cache — fetch from server.
      final user = await AuthService.fetchMe();
      if (user != null) {
        _currentUser = user;
      } else {
        // Token may be expired — attempt refresh.
        final refreshed = await AuthService.refreshIfNeeded();
        if (refreshed != null) {
          _currentUser = refreshed;
        } else {
          await _clearSession();
        }
      }
    } catch (e) {
      debugPrint('[AuthProvider] loadSession error: $e');
      await _clearSession();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Auth actions ──────────────────────────────────────────────────────────

  Future<void> login({required String email, required String password}) async {
    _error = null;
    final user = await AuthService.login(email: email, password: password);
    _currentUser = user;
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    String? name,
  }) async {
    _error = null;
    final user = await AuthService.register(
        email: email, password: password, name: name);
    _currentUser = user;
    notifyListeners();
  }

  Future<AppUser?> loginWithGoogle() async {
    _error = null;
    final user = await AuthService.signInWithGoogle();
    if (user == null) return null; // cancelled
    _currentUser = user;
    notifyListeners();
    return user;
  }

  Future<void> logout() async {
    await AuthService.signOut();
    _currentUser = null;
    _error = null;
    notifyListeners();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<void> _clearSession() async {
    await clearAuth();
    _currentUser = null;
  }

  Future<void> _refreshSilently() async {
    try {
      final refreshed = await AuthService.refreshIfNeeded();
      if (refreshed != null) {
        _currentUser = refreshed;
        notifyListeners();
      }
    } catch (_) {}
  }
}
