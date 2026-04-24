import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/wishlist_item.dart';
import '../../providers/wishlist_provider.dart';

/// Saved / wishlist screen.
///
/// HCI evaluation notes:
/// · H3 User control: clear-all has a confirmation dialog (error prevention).
/// · H4 Consistency: card layout matches results screen — same thumbnail + info.
/// · H6 Recognition: save date shown to help users recall when they saved items.
/// · H8 Minimalism: one-line source + delivery, no repeated decorations.
class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(wishlistProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Saved  (${items.length})'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, ref),
              child: const Text(
                'Clear all',
                style: TextStyle(color: AppTheme.error),
              ),
            ),
        ],
      ),
      body: items.isEmpty
          ? const _EmptyWishlist()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: items.length,
              itemBuilder: (ctx, i) => _WishlistCard(item: items[i]),
            ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: const Text('Clear wishlist?'),
        titleTextStyle: TextStyle(
          color:      cs.onSurface,
          fontSize:   17,
          fontWeight: FontWeight.w700,
        ),
        content: Text(
          'All saved items will be removed. This cannot be undone.',
          style: TextStyle(
            color:    isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(
                  color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
                )),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final notifier = ref.read(wishlistProvider.notifier);
      final copy     = List.of(ref.read(wishlistProvider));
      for (final item in copy) {
        notifier.remove(item.product);
      }
    }
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyWishlist extends StatelessWidget {
  const _EmptyWishlist();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
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
                color:  cs.surfaceContainerHighest,
                shape:  BoxShape.circle,
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Icon(
                Icons.bookmark_border_rounded,
                size:  36,
                color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No saved items',
              style: TextStyle(
                color:      cs.onSurface,
                fontSize:   17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the bookmark icon on any product\nto save it here for later.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:    isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
                fontSize: 14,
                height:   1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Wishlist card ────────────────────────────────────────────────────────────

class _WishlistCard extends ConsumerWidget {
  final WishlistItem item;
  const _WishlistCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final product = item.product;
    final img     = product.displayImage;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        cs.surface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Material(
        color:        Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap:        () => context.push('/product', extra: product),
          borderRadius: BorderRadius.circular(12),
          splashColor:  AppTheme.primary.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width:  76,
                    height: 76,
                    child: img != null
                        ? CachedNetworkImage(
                            imageUrl: img,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: isDark ? AppTheme.tagChipBg : AppTheme.tagChipBgLight,
                              child: const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: isDark ? AppTheme.tagChipBg : AppTheme.tagChipBgLight,
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                size:  28,
                                color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
                              ),
                            ),
                          )
                        : Container(
                            color: isDark ? AppTheme.tagChipBg : AppTheme.tagChipBgLight,
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              size:  36,
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
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize:   14,
                          color:      cs.onSurface,
                          height:     1.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (product.price != null)
                        Text(
                          product.price!,
                          style: const TextStyle(
                            color:      AppTheme.accent,
                            fontWeight: FontWeight.w700,
                            fontSize:   15,
                          ),
                        ),
                      if (product.source != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          product.source!,
                          style: TextStyle(
                            color:    cs.onSurface,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.bookmark_rounded,
                              size: 11,
                              color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight),
                          const SizedBox(width: 3),
                          Text(
                            'Saved ${_relativeDate(item.savedAt)}',
                            style: TextStyle(
                              color:    isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Remove button — 44×44 min touch target
                SizedBox(
                  width:  44,
                  height: 44,
                  child: IconButton(
                    icon: const Icon(
                      Icons.bookmark_remove_rounded,
                      color: AppTheme.accent,
                      size:  22,
                    ),
                    onPressed: () =>
                        ref.read(wishlistProvider.notifier).remove(product),
                    tooltip: 'Remove from saved',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7)  return '${diff.inDays} days ago';
    final weeks = (diff.inDays / 7).floor();
    return '$weeks week${weeks == 1 ? '' : 's'} ago';
  }
}
