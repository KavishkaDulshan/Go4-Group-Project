import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../core/utils/error_utils.dart';
import '../models/user_profile.dart';

const _prefToken = 'pref_token';
const _prefUserJson = 'pref_user_json';

// ─── Google client IDs ────────────────────────────────────────────────────────
// serverClientId MUST be the **Web application** OAuth 2.0 client ID from
// GCP Console → APIs & Services → Credentials.  It enables idToken issuance
// so the backend can verify sign-ins via POST /api/v1/auth/google.
// The value below comes from GOOGLE_CLIENT_ID in backend/.env.
const _webClientId =
    '642859857652-8grqto8t2mjlm8r3g98ig8relhk36ouj.apps.googleusercontent.com';

final _googleSignIn = GoogleSignIn(
  scopes: ['email', 'profile'],
  serverClientId: _webClientId,
);

// ── State ─────────────────────────────────────────────────────────────────────

class AuthState {
  final UserProfile? user;
  final String? token;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isSignedIn => user != null && token != null;

  AuthState copyWith({
    UserProfile? user,
    String? token,
    bool? isLoading,
    String? errorMessage,
  }) =>
      AuthState(
        user: user ?? this.user,
        token: token ?? this.token,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  /// Reload persisted JWT + user from SharedPreferences on app start.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_prefToken);
    final userJson = prefs.getString(_prefUserJson);
    if (token != null && userJson != null) {
      try {
        final user = UserProfile.fromJson(
          jsonDecode(userJson) as Map<String, dynamic>,
        );
        ApiClient.instance.setAuthToken(token);
        state = state.copyWith(user: user, token: token);
      } catch (_) {
        // Corrupted prefs — clear and stay signed-out
        await prefs.remove(_prefToken);
        await prefs.remove(_prefUserJson);
      }
    }
  }

  /// Google Sign-In → backend verification → persist JWT.
  Future<void> signIn() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled
        state = state.copyWith(isLoading: false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw Exception('Google did not return an ID token.');
      }

      final data = await ApiClient.instance.signInWithGoogle(idToken);
      final token = data['token'] as String;
      final user = UserProfile.fromJson(data['user'] as Map<String, dynamic>);

      ApiClient.instance.setAuthToken(token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefToken, token);
      await prefs.setString(_prefUserJson, jsonEncode(user.toJson()));

      state = AuthState(user: user, token: token);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: friendlyError(e));
    }
  }

  /// Sign out — clear Google session + local prefs + reset state.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefToken);
    await prefs.remove(_prefUserJson);
    ApiClient.instance.setAuthToken(null);
    state = const AuthState();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((_) => AuthNotifier());
