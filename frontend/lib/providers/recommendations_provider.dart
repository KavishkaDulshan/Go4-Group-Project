import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/utils/error_utils.dart';
import '../models/product.dart';
import '../models/user_preferences.dart';
import 'auth_provider.dart';

// ── Response model ────────────────────────────────────────────────────────────

class RecommendationsState {
  final bool isLoading;
  final String? errorMessage;
  final UserPreferences? preferences;
  final List<Product> recommendations;
  final String? query;
  final String? message; // shown when user needs more searches

  const RecommendationsState({
    this.isLoading = false,
    this.errorMessage,
    this.preferences,
    this.recommendations = const [],
    this.query,
    this.message,
  });

  RecommendationsState copyWith({
    bool? isLoading,
    String? errorMessage,
    UserPreferences? preferences,
    List<Product>? recommendations,
    String? query,
    String? message,
  }) {
    return RecommendationsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      preferences: preferences ?? this.preferences,
      recommendations: recommendations ?? this.recommendations,
      query: query ?? this.query,
      message: message,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final recommendationsProvider =
    StateNotifierProvider<RecommendationsNotifier, RecommendationsState>(
  (ref) => RecommendationsNotifier(ref),
);

class RecommendationsNotifier extends StateNotifier<RecommendationsState> {
  final Ref _ref;

  RecommendationsNotifier(this._ref) : super(const RecommendationsState());

  /// Fetch recommendations + preference profile from the backend.
  Future<void> fetch() async {
    final isSignedIn = _ref.read(authProvider).isSignedIn;
    if (!isSignedIn) {
      state = state.copyWith(
        isLoading: false,
        message: 'Sign in to see personalised recommendations.',
      );
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      final raw = await ApiClient.instance.getRecommendations();

      final prefs = raw['preferences'] != null
          ? UserPreferences.fromJson(raw['preferences'] as Map<String, dynamic>)
          : null;

      final results = raw['recommendations'] as List<dynamic>? ?? [];
      final products = results
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        isLoading: false,
        preferences: prefs,
        recommendations: products,
        query: raw['query'] as String?,
        message: raw['message'] as String?,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: friendlyError(e),
      );
    }
  }
}
