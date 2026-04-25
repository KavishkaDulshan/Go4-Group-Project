import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_enrichment.dart';
import '../models/product_review.dart';
import 'search_provider.dart';

/// In-memory cache for product enrichment and review data.
///
/// Keyed by product URL (link) or title as fallback.
/// Automatically cleared when a new search completes — so cached data
/// always belongs to the current search session.
class ProductCacheState {
  final Map<String, ProductEnrichment> enrichments;
  final Map<String, ProductReviewResult> reviews;

  const ProductCacheState({
    this.enrichments = const {},
    this.reviews = const {},
  });

  ProductCacheState copyWith({
    Map<String, ProductEnrichment>? enrichments,
    Map<String, ProductReviewResult>? reviews,
  }) =>
      ProductCacheState(
        enrichments: enrichments ?? this.enrichments,
        reviews: reviews ?? this.reviews,
      );
}

class ProductCacheNotifier extends StateNotifier<ProductCacheState> {
  ProductCacheNotifier() : super(const ProductCacheState());

  // ── Enrichment ──────────────────────────────────────────────────────────────

  ProductEnrichment? getEnrichment(String key) => state.enrichments[key];

  void setEnrichment(String key, ProductEnrichment data) {
    state = state.copyWith(
      enrichments: Map.unmodifiable({...state.enrichments, key: data}),
    );
  }

  // ── Reviews ─────────────────────────────────────────────────────────────────

  ProductReviewResult? getReviews(String key) => state.reviews[key];

  void setReviews(String key, ProductReviewResult data) {
    state = state.copyWith(
      reviews: Map.unmodifiable({...state.reviews, key: data}),
    );
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  /// Wipe all cached data (called when a new search starts).
  void clear() => state = const ProductCacheState();
}

final productCacheProvider =
    StateNotifierProvider<ProductCacheNotifier, ProductCacheState>((ref) {
  final notifier = ProductCacheNotifier();

  // Auto-clear cache whenever a new search result arrives
  // (searchId changes = entirely new search session)
  ref.listen<SearchState>(searchProvider, (prev, next) {
    if (next.status == SearchStatus.success &&
        prev?.result?.searchId != next.result?.searchId) {
      notifier.clear();
    }
  });

  return notifier;
});
