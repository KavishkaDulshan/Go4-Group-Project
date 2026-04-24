import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/utils/error_utils.dart';
import '../models/history_item.dart';
import '../models/search_filter.dart';
import '../models/search_result.dart';

enum SearchStatus { idle, analyzing, analyzed, processing, success, error }

class SearchState {
  final SearchStatus status;
  final SearchResult? result;
  final String? errorMessage;
  final String? capturedImagePath;
  final String? capturedAudioPath;

  /// Optional plain-text query entered via the keyboard search sheet.
  final String? capturedText;

  /// Tags returned by the analyze step (used to build the final search query).
  final Map<String, dynamic>? analyzedTags;

  /// AI-generated filters populated after the analyze step.
  final List<SearchFilter>? pendingFilters;

  const SearchState({
    this.status = SearchStatus.idle,
    this.result,
    this.errorMessage,
    this.capturedImagePath,
    this.capturedAudioPath,
    this.capturedText,
    this.analyzedTags,
    this.pendingFilters,
  });

  SearchState copyWith({
    SearchStatus? status,
    SearchResult? result,
    String? errorMessage,
    String? capturedImagePath,
    String? capturedAudioPath,
    String? capturedText,
    Map<String, dynamic>? analyzedTags,
    List<SearchFilter>? pendingFilters,
  }) =>
      SearchState(
        status:            status            ?? this.status,
        result:            result            ?? this.result,
        errorMessage:      errorMessage      ?? this.errorMessage,
        capturedImagePath: capturedImagePath ?? this.capturedImagePath,
        capturedAudioPath: capturedAudioPath ?? this.capturedAudioPath,
        capturedText:      capturedText      ?? this.capturedText,
        analyzedTags:      analyzedTags      ?? this.analyzedTags,
        pendingFilters:    pendingFilters    ?? this.pendingFilters,
      );

  /// True when the user has at least one input ready.
  bool get hasInput =>
      capturedImagePath != null || capturedAudioPath != null ||
      (capturedText != null && capturedText!.isNotEmpty);
}

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier() : super(const SearchState());

  void captureImage(String path) =>
      state = state.copyWith(capturedImagePath: path);

  void captureAudio(String path) =>
      state = state.copyWith(capturedAudioPath: path);

  void captureText(String text) =>
      state = state.copyWith(capturedText: text);

  void clearAudio() => state = SearchState(
        capturedImagePath: state.capturedImagePath,
        capturedText:      state.capturedText,
      );

  void clearImage() => state = SearchState(
        capturedAudioPath: state.capturedAudioPath,
        capturedText:      state.capturedText,
      );

  void clearText() => state = SearchState(
        capturedImagePath: state.capturedImagePath,
        capturedAudioPath: state.capturedAudioPath,
      );

  // ── Step 1: Analyze inputs → tags + smart filters ─────────────────────────

  Future<void> analyzeInputs() async {
    state = state.copyWith(status: SearchStatus.analyzing);
    try {
      final analyzeResult = await ApiClient.instance.analyzeSearch(
        imagePath: state.capturedImagePath,
        audioPath: state.capturedAudioPath,
        query:     state.capturedText,
      );

      state = state.copyWith(
        status:         SearchStatus.analyzed,
        analyzedTags:   analyzeResult.tags,
        pendingFilters: analyzeResult.filters,
      );
    } catch (e) {
      state = state.copyWith(
        status:       SearchStatus.error,
        errorMessage: friendlyError(e),
      );
    }
  }

  // ── Step 2: Submit with selected filters → product results ────────────────

  Future<void> submitWithFilters(List<SearchFilter> filters) async {
    state = state.copyWith(status: SearchStatus.processing);
    try {
      final tags = state.analyzedTags ?? {};

      // ── Detect if the brand filter was explicitly changed by the user ─────
      // A brand override means the AI's detected brand was deselected, so the
      // entire AI-generated searchQuery (e.g. "AMD Ryzen Laptop ...") is
      // brand-opinionated and cannot be used as-is — stripping just "AMD" still
      // leaves brand-specific processor terms like "Ryzen".
      final brandFilter = filters.cast<SearchFilter?>().firstWhere(
        (f) => f?.key == 'brand',
        orElse: () => null,
      );
      final brandOverridden = brandFilter != null &&
          brandFilter.defaultValue != null &&
          brandFilter.defaultValue!.isNotEmpty &&
          !brandFilter.selectedValues.contains(brandFilter.defaultValue);

      // ── Build a brand-neutral base when brand was overridden ──────────────
      // Use category + style tags — both are brand-agnostic.
      // Example: category="Laptops", style="productivity" → "Laptops productivity"
      // This avoids AMD-specific "Ryzen", Nvidia-specific "GeForce", etc.
      String base;
      if (brandOverridden) {
        final category = (tags['category'] as String? ?? '').trim();
        final style    = (tags['style']    as String? ?? '').trim();
        base = [category, style].where((s) => s.isNotEmpty).join(' ');
      } else {
        // Brand unchanged: start from the full AI searchQuery, then strip any
        // other filter defaultValues the user explicitly deselected.
        base = (tags['searchQuery'] as String? ?? '').trim();
        for (final f in filters) {
          final d = f.defaultValue;
          if (d != null && d.isNotEmpty && !f.selectedValues.contains(d)) {
            base = base
                .replaceAll(RegExp(RegExp.escape(d), caseSensitive: false), '')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
          }
        }
      }

      // ── Append user-selected filter values ────────────────────────────────
      // Skip any value already present in base to prevent duplication
      // (e.g. "black" appearing in both searchQuery and the color filter).
      final lowerBase = base.toLowerCase();
      final extras = filters
          .expand((f) => f.selectedValues)
          .where((v) => v.isNotEmpty)
          .where((v) => !lowerBase.contains(v.toLowerCase()))
          .toList();

      final enrichedQuery = [base, ...extras]
          .where((s) => s.isNotEmpty)
          .join(' ');

      // Do NOT re-send image or audio — that would trigger Gemini re-analysis
      // and overwrite the filter-enriched query.
      final result = await ApiClient.instance.search(
        query: enrichedQuery.isEmpty ? null : enrichedQuery,
      );
      state = state.copyWith(status: SearchStatus.success, result: result);
    } catch (e) {
      state = state.copyWith(
        status:       SearchStatus.error,
        errorMessage: friendlyError(e),
      );
    }
  }

  // ── Legacy direct search ──────────────────────────────────────────────────

  Future<void> submitSearch() async {
    state = state.copyWith(status: SearchStatus.processing);
    try {
      final result = await ApiClient.instance.search(
        imagePath: state.capturedImagePath,
        audioPath: state.capturedAudioPath,
      );
      state = state.copyWith(status: SearchStatus.success, result: result);
    } catch (e) {
      state = state.copyWith(
        status:       SearchStatus.error,
        errorMessage: friendlyError(e),
      );
    }
  }

  void reset() => state = const SearchState();

  /// Load a [HistoryItem] into state so the results screen can display it.
  void loadHistory(HistoryItem item) {
    final result = SearchResult(
      searchId: item.searchId,
      tags:     item.tags,
      results:  item.results,
    );
    state = SearchState(status: SearchStatus.success, result: result);
  }
}

final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((_) => SearchNotifier());
