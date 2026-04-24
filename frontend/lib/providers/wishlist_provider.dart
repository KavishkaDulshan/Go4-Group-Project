import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/wishlist_item.dart';

const _kWishlistKey = 'go4_wishlist_v1';

class WishlistNotifier extends StateNotifier<List<WishlistItem>> {
  WishlistNotifier() : super([]) {
    _load();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kWishlistKey) ?? [];
      state = raw
          .map((s) {
            try {
              return WishlistItem.fromJson(
                  jsonDecode(s) as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<WishlistItem>()
          .toList();
    } catch (_) {
      state = [];
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _kWishlistKey,
        state.map((item) => jsonEncode(item.toJson())).toList(),
      );
    } catch (_) {}
  }

  // ── Operations ────────────────────────────────────────────────────────────

  /// Returns true if [product] is already in the wishlist.
  bool contains(Product product) =>
      state.any((item) => sameProduct(item.product, product));

  void add(Product product) {
    if (contains(product)) return;
    state = [
      WishlistItem(product: product, savedAt: DateTime.now()),
      ...state,
    ];
    _save();
  }

  void remove(Product product) {
    state = state.where((item) => !sameProduct(item.product, product)).toList();
    _save();
  }

  void toggle(Product product) =>
      contains(product) ? remove(product) : add(product);

  // ── Key equality ──────────────────────────────────────────────────────────

  static bool sameProduct(Product a, Product b) {
    if (a.link != null && b.link != null) return a.link == b.link;
    return a.title == b.title;
  }
}

final wishlistProvider =
    StateNotifierProvider<WishlistNotifier, List<WishlistItem>>(
  (_) => WishlistNotifier(),
);
