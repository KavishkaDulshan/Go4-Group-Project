import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_utils.dart';
import '../../models/history_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/search_provider.dart';

/// Search history screen.
///
/// HCI evaluation notes:
/// · H1 Visibility of system status — loading/error/empty states all explicit.
/// · H2 Match between system and real world — time-ago language ("2h ago").
/// · H5 Error prevention — sign-in nudge explains why history is empty.
/// · H8 Aesthetic minimalism — single row per item, no visual noise.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth    = ref.watch(authProvider);
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorState(message: friendlyError(err)),
        data: (items) {
          if (!auth.isSignedIn) {
            return const _SignInNudge();
          }
          if (items.isEmpty) {
            return const _EmptyHistory();
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length,
            itemBuilder: (ctx, i) => _HistoryCard(
              item:  items[i],
              onTap: () {
                ref.read(searchProvider.notifier).loadHistory(items[i]);
                ctx.push('/results');
              },
            ),
          );
        },
      ),
    );
  }
}

// ─── States ───────────────────────────────────────────────────────────────────

class _SignInNudge extends StatelessWidget {
  const _SignInNudge();

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
                Icons.lock_outline_rounded,
                size:  36,
                color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sign in to view history',
              style: TextStyle(
                color:      cs.onSurface,
                fontSize:   17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your past searches sync across\nall your devices automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:    isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
                fontSize: 14,
                height:   1.5,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Go to Account tab to sign in',
              style: TextStyle(
                color:    AppTheme.primary.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

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
                Icons.search_off_rounded,
                size:  36,
                color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No searches yet',
              style: TextStyle(
                color:      cs.onSurface,
                fontSize:   17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Point your camera at a product\nor type a description to get started.',
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

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 48, color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight),
            const SizedBox(height: 16),
            Text(
              'Could not load history',
              style: TextStyle(
                color:      cs.onSurface,
                fontSize:   16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
                  fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── History card ─────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final HistoryItem  item;
  final VoidCallback onTap;

  const _HistoryCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final thumbs = item.results
        .where((p) => p.thumbnail != null)
        .take(3)
        .map((p) => p.thumbnail!)
        .toList();
    final chips = item.tags.chips.take(3).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:        cs.surface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Material(
        color:        Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap:        onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor:  AppTheme.primary.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Thumbnail stack
                SizedBox(
                  width:  72,
                  height: 56,
                  child:  thumbs.isEmpty
                      ? Container(
                          width:  56,
                          height: 56,
                          decoration: BoxDecoration(
                            color:        isDark ? AppTheme.tagChipBg : AppTheme.tagChipBgLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            size:  26,
                            color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
                          ),
                        )
                      : _ThumbnailStack(urls: thumbs),
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.tags.productName.isNotEmpty
                            ? item.tags.productName
                            : item.tags.searchQuery,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize:   14,
                          color:      cs.onSurface,
                        ),
                      ),
                      if (chips.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 4,
                          children: chips
                              .map((c) => _MiniChip(c))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 5),
                      Text(
                        '${item.results.length} result'
                        '${item.results.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          color:    isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Time + chevron
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _timeAgo(item.createdAt),
                      style: TextStyle(
                        color:    isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    if (diff.inDays < 7)      return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

// ─── Mini chip ────────────────────────────────────────────────────────────────

class _MiniChip extends StatelessWidget {
  final String text;
  const _MiniChip(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color:        isDark ? AppTheme.tagChipBg : AppTheme.tagChipBgLight,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          color:    cs.onSurface,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─── Thumbnail stack ──────────────────────────────────────────────────────────

class _ThumbnailStack extends StatelessWidget {
  final List<String> urls;
  const _ThumbnailStack({required this.urls});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const sz      = 44.0;
    const overlap = 10.0;
    final count   = urls.length.clamp(1, 3);

    return SizedBox(
      width:  sz + (count - 1) * overlap,
      height: sz,
      child: Stack(
        children: List.generate(count, (i) => Positioned(
          left: i * overlap.toDouble(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CachedNetworkImage(
              imageUrl: urls[i],
              width:    sz,
              height:   sz,
              fit:      BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width:  sz,
                height: sz,
                color:  isDark ? AppTheme.tagChipBg : AppTheme.tagChipBgLight,
                child:  Icon(Icons.image_not_supported_outlined,
                    size: 18, color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight),
              ),
            ),
          ),
        )),
      ),
    );
  }
}
