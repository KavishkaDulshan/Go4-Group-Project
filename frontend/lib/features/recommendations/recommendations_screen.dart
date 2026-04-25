import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/product.dart';
import '../../models/user_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/recommendations_provider.dart';

/// Personalised Recommendations screen.
///
/// · Shows the learned preference profile as labelled chip rows.
/// · Displays a product grid built from the user's top preferences.
/// · Falls back to a sign-in nudge or "search more" prompt when data is thin.
class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState extends ConsumerState<RecommendationsScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger fetch on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recommendationsProvider.notifier).fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recommendationsProvider);
    final isSignedIn = ref.watch(authProvider).isSignedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('For You'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.read(recommendationsProvider.notifier).fetch(),
          ),
        ],
      ),
      body: _buildBody(state, isSignedIn),
    );
  }

  Widget _buildBody(RecommendationsState state, bool isSignedIn) {
    if (!isSignedIn) {
      return const _SignInNudge();
    }

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null) {
      return _ErrorState(
          message: state.errorMessage!,
          onRetry: () => ref.read(recommendationsProvider.notifier).fetch());
    }

    if (state.message != null && state.recommendations.isEmpty) {
      return _NotEnoughData(
        message: state.message!,
        searchCount: state.preferences?.searchCount ?? 0,
      );
    }

    return CustomScrollView(
      slivers: [
        // ── Preference profile header ──────────────────────────────────────
        if (state.preferences != null)
          SliverToBoxAdapter(
            child: _PreferenceHeader(preferences: state.preferences!),
          ),

        // ── Section label ──────────────────────────────────────────────────
        if (state.query != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RECOMMENDED FOR YOU',
                    style: TextStyle(
                      color: AppTheme.onSurfaceMid,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Based on: "${state.query}"',
                    style: const TextStyle(
                      color: AppTheme.onSurfaceMid,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Product grid ───────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _ProductCard(
                product: state.recommendations[index],
              ),
              childCount: state.recommendations.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.70,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Preference header ────────────────────────────────────────────────────────

class _PreferenceHeader extends StatelessWidget {
  final UserPreferences preferences;
  const _PreferenceHeader({required this.preferences});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.psychology_rounded,
                    size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Taste Profile',
                      style: TextStyle(
                        color: AppTheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${preferences.searchCount} searches analysed',
                      style: const TextStyle(
                        color: AppTheme.onSurfaceMid,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (preferences.allCategories.isNotEmpty)
            _PrefRow(label: 'Categories', entries: preferences.allCategories),
          if (preferences.allMaterials.isNotEmpty)
            _PrefRow(label: 'Materials', entries: preferences.allMaterials),
          if (preferences.allStyles.isNotEmpty)
            _PrefRow(label: 'Styles', entries: preferences.allStyles),
          if (preferences.allColors.isNotEmpty)
            _PrefRow(label: 'Colors', entries: preferences.allColors),
          if (preferences.priceRange?.avg != null) ...[
            const SizedBox(height: 6),
            Text(
              'Typical spend: \$${preferences.priceRange!.avg!.toStringAsFixed(0)} avg'
              '  ·  \$${preferences.priceRange!.min!.toStringAsFixed(0)}–\$${preferences.priceRange!.max!.toStringAsFixed(0)} range',
              style: const TextStyle(
                color: AppTheme.onSurfaceMid,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrefRow extends StatelessWidget {
  final String label;
  final List<PreferenceEntry> entries;
  const _PrefRow({required this.label, required this.entries});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.onSurfaceMid,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: entries.map((e) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    '${e.value}  ×${e.count}',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Product card ─────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final img = product.displayImage;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => context.push('/product', extra: product),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: img != null
                    ? CachedNetworkImage(
                        imageUrl: img,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorWidget: (_, __, ___) => const _ImagePlaceholder(),
                        placeholder: (_, __) =>
                            const _ImagePlaceholder(loading: true),
                      )
                    : const _ImagePlaceholder(),
              ),
            ),
            // Info
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    if (product.price != null)
                      Text(
                        product.price!,
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (product.source != null)
                      Text(
                        product.source!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.onSurfaceMid,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final bool loading;
  const _ImagePlaceholder({this.loading = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      child: Center(
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.image_not_supported_outlined,
                color: AppTheme.onSurfaceMid, size: 28),
      ),
    );
  }
}

// ─── Empty states ─────────────────────────────────────────────────────────────

class _SignInNudge extends StatelessWidget {
  const _SignInNudge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border:
                    Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 36, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'Personalised Recommendations',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Sign in so GO4 can learn your preferences\nand recommend products you love.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.onSurfaceMid,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.person_rounded, size: 18),
                label: const Text('Go to Account'),
                onPressed: () => context.go('/profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotEnoughData extends StatelessWidget {
  final String message;
  final int searchCount;
  const _NotEnoughData({required this.message, required this.searchCount});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border:
                    Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.bar_chart_rounded,
                  size: 36, color: AppTheme.accent),
            ),
            const SizedBox(height: 20),
            const Text(
              'Still Learning',
              style: TextStyle(
                color: AppTheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.onSurfaceMid,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$searchCount searches recorded so far',
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: const Text('Start Searching'),
                onPressed: () => context.go('/'),
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
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppTheme.onSurfaceMid, fontSize: 13),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
