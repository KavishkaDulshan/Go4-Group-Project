import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/product.dart';
import '../../providers/search_provider.dart';
import '../../providers/wishlist_provider.dart';

// ── Sort options ──────────────────────────────────────────────────────────────

enum _SortOption {
  relevance('Relevance'),
  priceLow('Price: Low → High'),
  priceHigh('Price: High → Low'),
  rating('Rating');

  final String label;
  const _SortOption(this.label);
}

double _parsePrice(String? price) {
  if (price == null || price.isEmpty) return double.infinity;
  final cleaned = price.replaceAll(RegExp(r'[^\d.]'), '');
  return double.tryParse(cleaned) ?? double.infinity;
}

List<Product> _sorted(List<Product> products, _SortOption opt) {
  final copy = List.of(products);
  switch (opt) {
    case _SortOption.relevance:
      return copy;
    case _SortOption.priceLow:
      copy.sort((a, b) => _parsePrice(a.price).compareTo(_parsePrice(b.price)));
    case _SortOption.priceHigh:
      copy.sort((a, b) => _parsePrice(b.price).compareTo(_parsePrice(a.price)));
    case _SortOption.rating:
      copy.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
  }
  return copy;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  _SortOption _sort = _SortOption.relevance;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final state  = ref.watch(searchProvider);
    final result = state.result;

    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Results')),
        body: Center(
          child: Text('No results yet.',
              style: TextStyle(
                  color: isDark ? Colors.white54 : AppTheme.onSurfaceMidLight)),
        ),
      );
    }

    final products = _sorted(result.results, _sort);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              result.tags.productName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${products.length} results',
              style: const TextStyle(
                fontSize: 11,
                color:    AppTheme.onSurfaceMid,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          // Sort menu
          PopupMenuButton<_SortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: _sort,
            onSelected: (opt) => setState(() => _sort = opt),
            itemBuilder: (_) => _SortOption.values
                .map((opt) => PopupMenuItem(
                      value: opt,
                      child: Row(
                        children: [
                          Icon(
                            _sort == opt
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 16,
                            color: _sort == opt
                                ? AppTheme.primary
                                : (isDark ? Colors.white38 : AppTheme.onSurfaceLowLight),
                          ),
                          const SizedBox(width: 8),
                          Text(opt.label),
                        ],
                      ),
                    ))
                .toList(),
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'View on Map',
            onPressed: () => context.go('/map'),
          ),
        ],
        bottom: result.tags.chips.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    children: result.tags.chips
                        .map((c) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Chip(label: Text(c)),
                            ))
                        .toList(),
                  ),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          // Active sort indicator bar
          if (_sort != _SortOption.relevance)
            Container(
              color: AppTheme.primary.withValues(alpha: 0.1),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.sort, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Sorted by: ${_sort.label}',
                    style: const TextStyle(
                        color: AppTheme.primary, fontSize: 12),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _sort = _SortOption.relevance),
                    child: Text('Reset',
                        style: TextStyle(
                            color: isDark ? Colors.white38 : AppTheme.onSurfaceLowLight,
                            fontSize: 12)),
                  ),
                ],
              ),
            ),

          Expanded(
            child: products.isEmpty
                ? _EmptyResults(query: result.tags.searchQuery)
                : ListView.builder(
                    padding:    const EdgeInsets.fromLTRB(12, 8, 12, 20),
                    itemCount:  products.length,
                    itemBuilder: (ctx, i) => _AnimatedCard(
                      index:   i,
                      child:   _ProductCard(product: products[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Staggered entry animation wrapper ────────────────────────────────────────

class _AnimatedCard extends StatefulWidget {
  final int    index;
  final Widget child;
  const _AnimatedCard({required this.index, required this.child});

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _opacity;
  late final Animation<Offset>   _slide;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 340),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Stagger: first 8 items animate, rest load instantly
    final delay = widget.index < 8
        ? Duration(milliseconds: widget.index * 45)
        : Duration.zero;

    if (delay == Duration.zero) {
      _ctrl.forward();
    } else {
      _timer = Timer(delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child:   SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyResults extends StatelessWidget {
  final String query;
  const _EmptyResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  80,
              height: 80,
              decoration: BoxDecoration(
                shape:    BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.2),
                    AppTheme.primary.withValues(alpha: 0.04),
                  ],
                ),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size:  38,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No results for "$query".',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color:      AppTheme.onSurface,
                fontSize:   16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try a broader description\nor take a clearer photo.',
              textAlign: TextAlign.center,
              style:     TextStyle(color: AppTheme.onSurfaceMid, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Product card ─────────────────────────────────────────────────────────────

class _ProductCard extends ConsumerWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final img    = product.displayImage;
    final isSaved = ref.watch(
      wishlistProvider.select(
        (list) => list.any((item) => WishlistNotifier.sameProduct(item.product, product)),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Theme.of(context).dividerColor,
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color:        Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap:        () => context.push('/product', extra: product),
          borderRadius: BorderRadius.circular(16),
          splashColor:  AppTheme.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width:  80,
                    height: 80,
                    child: img != null
                        ? CachedNetworkImage(
                            imageUrl:    img,
                            fit:         BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: isDark ? AppTheme.tagChipBg : AppTheme.tagChipBgLight,
                              child: const Center(
                                child: SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:       AppTheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color:  isDark ? AppTheme.tagChipBg : AppTheme.tagChipBgLight,
                              child:  Icon(
                                Icons.image_not_supported_outlined,
                                size:  28,
                                color: isDark ? Colors.white24 : AppTheme.surfaceBorderLight,
                              ),
                            ),
                          )
                        : Container(
                            color: isDark ? AppTheme.tagChipBg : AppTheme.tagChipBgLight,
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              size:  32,
                              color: AppTheme.primary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        maxLines:  2,
                        overflow:  TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize:   14,
                          color:      AppTheme.onSurface,
                          height:     1.3,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Price row
                      if (product.price != null)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              product.price!,
                              style: const TextStyle(
                                color:      AppTheme.accent,
                                fontWeight: FontWeight.w800,
                                fontSize:   16,
                              ),
                            ),
                            if (product.originalPrice != null) ...[
                              const SizedBox(width: 7),
                              Text(
                                product.originalPrice!,
                                style: TextStyle(
                                  color:      isDark ? Colors.white38 : AppTheme.onSurfaceLowLight,
                                  fontSize:   12,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ],
                        ),
                      const SizedBox(height: 3),

                      // Source
                      if (product.source != null)
                        Text(
                          product.source!,
                          style: const TextStyle(
                            color:   AppTheme.onSurfaceMid,
                            fontSize: 12,
                          ),
                        ),

                      // Delivery
                      if (product.delivery != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.local_shipping_outlined,
                                size: 11, color: Colors.green),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                product.delivery!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color:   Colors.green,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Rating
                      if (product.rating != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 14, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              '${product.rating!.toStringAsFixed(1)}'
                              '${product.ratingCount != null ? ' (${product.ratingCount})' : ''}',
                              style: const TextStyle(
                                color:   AppTheme.onSurfaceMid,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Right column: wishlist + verified + chevron
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () =>
                          ref.read(wishlistProvider.notifier).toggle(product),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          key:   ValueKey(isSaved),
                          size:  22,
                          color: isSaved
                              ? Colors.pinkAccent
                              : (isDark ? Colors.white38 : AppTheme.onSurfaceLowLight),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const _VerifiedBadge(),
                    const SizedBox(height: 6),
                    Icon(Icons.chevron_right_rounded,
                        size: 18,
                        color: isDark ? Colors.white38 : AppTheme.onSurfaceLowLight),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 11, color: Colors.green),
          SizedBox(width: 3),
          Text(
            'Live',
            style: TextStyle(
                color: Colors.green,
                fontSize: 10,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
