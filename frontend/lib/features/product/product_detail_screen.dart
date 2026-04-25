import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/product.dart';
import '../../models/product_enrichment.dart';
import '../../models/product_review.dart';
import '../../providers/product_cache_provider.dart';
import '../../providers/search_provider.dart';

/// Full-screen product detail view with Gemini-enriched specifications.
/// Receives a [Product] via GoRouter `extra`:
///   context.push('/product', extra: product);
class ProductDetailScreen extends ConsumerStatefulWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  ProductEnrichment? _enrichment;
  bool _isLoadingEnrichment = true;
  String? _enrichmentError;

  // ── Review analysis state ─────────────────────────────────────────────────
  ProductReviewResult? _reviews;
  bool _isLoadingReviews = false;
  bool _reviewsLoaded = false;
  String? _reviewsError;

  /// Stable key for this product in the cache: prefer URL, fall back to title.
  String get _cacheKey => widget.product.link ?? widget.product.title;

  @override
  void initState() {
    super.initState();
    _loadEnrichment();
  }

  Future<void> _loadEnrichment() async {
    final cache = ref.read(productCacheProvider.notifier);

    // Return immediately if already cached — no API call needed
    final cached = cache.getEnrichment(_cacheKey);
    if (cached != null) {
      setState(() {
        _enrichment = cached;
        _isLoadingEnrichment = false;
      });
      return;
    }

    final tags = ref.read(searchProvider).result?.tags;
    try {
      final enriched = await ApiClient.instance.enrichProduct(
        title: widget.product.title,
        category: tags?.category,
        source: widget.product.source,
        price: widget.product.price,
      );
      // Save to cache so subsequent opens skip the API call
      cache.setEnrichment(_cacheKey, enriched);
      if (mounted) {
        setState(() {
          _enrichment = enriched;
          _isLoadingEnrichment = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _enrichmentError = e.toString();
          _isLoadingEnrichment = false;
        });
      }
    }
  }

  Future<void> _loadReviews() async {
    if (_isLoadingReviews || _reviewsLoaded) return;

    final cache = ref.read(productCacheProvider.notifier);

    // Return immediately if already cached — no API call needed
    final cachedReviews = cache.getReviews(_cacheKey);
    if (cachedReviews != null) {
      setState(() {
        _reviews = cachedReviews;
        _reviewsLoaded = true;
        _isLoadingReviews = false;
      });
      return;
    }

    setState(() => _isLoadingReviews = true);
    final tags = ref.read(searchProvider).result?.tags;
    try {
      final result = await ApiClient.instance.getProductReviews(
        title: widget.product.title,
        category: tags?.category,
      );
      // Save to cache
      cache.setReviews(_cacheKey, result);
      if (mounted) {
        setState(() {
          _reviews = result;
          _reviewsLoaded = true;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reviewsError = e.toString();
          _reviewsLoaded = true;
          _isLoadingReviews = false;
        });
      }
    }
  }

  Future<void> _visitWebsite() async {
    if (widget.product.link == null) return;
    final uri = Uri.parse(widget.product.link!);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // silently ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final product = widget.product;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero image ───────────────────────────────────────────────────
            _HeroImage(url: product.displayImage),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title ────────────────────────────────────────────────
                  Text(
                    product.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Price block ──────────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (product.price != null)
                        Text(
                          product.price!,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accent,
                          ),
                        ),
                      if (product.originalPrice != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          product.originalPrice!,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white38 : AppTheme.onSurfaceLowLight,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        if (product.price != null) ...[
                          const SizedBox(width: 8),
                          _SavingsBadge(
                            current: product.price!,
                            original: product.originalPrice!,
                          ),
                        ],
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Rating row ───────────────────────────────────────────
                  if (product.rating != null) ...[
                    _RatingRow(
                        rating: product.rating!, count: product.ratingCount),
                    const SizedBox(height: 12),
                  ],

                  // ── Delivery + Offers badges ─────────────────────────────
                  if (product.delivery != null || product.offers != null)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (product.delivery != null)
                          _Badge(
                            icon: Icons.local_shipping_outlined,
                            label: product.delivery!,
                            color: Colors.green,
                          ),
                        if (product.offers != null && product.offers! > 1)
                          _Badge(
                            icon: Icons.store_outlined,
                            label: '${product.offers} more offers',
                            color: AppTheme.primary,
                          ),
                      ],
                    ),

                  Divider(
                    color: isDark ? Colors.white12 : AppTheme.surfaceBorderLight,
                    height: 32,
                  ),

                  // ── Store info ───────────────────────────────────────────
                  if (product.source != null)
                    _InfoTile(
                      icon: Icons.store_outlined,
                      label: 'Sold by',
                      value: product.source!,
                    ),
                  if (product.link != null)
                    _InfoTile(
                      icon: Icons.link,
                      label: 'Website',
                      value: _shortenUrl(product.link!),
                    ),

                  Divider(
                    color: isDark ? Colors.white12 : AppTheme.surfaceBorderLight,
                    height: 32,
                  ),

                  // ── AI-enriched content ──────────────────────────────────
                  if (_isLoadingEnrichment)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(
                              'Loading product details…',
                              style: TextStyle(
                                  color: isDark ? Colors.white38 : AppTheme.onSurfaceLowLight,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_enrichment != null) ...[
                    // Description
                    if (_enrichment!.description.isNotEmpty) ...[
                      const _SectionHeader(label:'About this product'),
                      const SizedBox(height: 8),
                      Text(
                        _enrichment!.description,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : AppTheme.onSurfaceLight,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Features
                    if (_enrichment!.features.isNotEmpty) ...[
                      const _SectionHeader(label:'Key Features'),
                      const SizedBox(height: 10),
                      ..._enrichment!.features.map((f) => _FeatureRow(text: f)),
                      const SizedBox(height: 20),
                    ],

                    // Specifications
                    if (_enrichment!.specifications.isNotEmpty) ...[
                      const _SectionHeader(label:'Specifications'),
                      const SizedBox(height: 10),
                      ..._enrichment!.specifications
                          .map((s) => _SpecRow(spec: s)),
                      const SizedBox(height: 20),
                    ],

                    // Compatibility
                    if (_enrichment!.compatibility != null &&
                        _enrichment!.compatibility!.isNotEmpty) ...[
                      const _SectionHeader(label:'Compatibility'),
                      const SizedBox(height: 8),
                      Text(
                        _enrichment!.compatibility!,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : AppTheme.onSurfaceLight,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Best For
                    if (_enrichment!.bestFor != null &&
                        _enrichment!.bestFor!.isNotEmpty) ...[
                      const _SectionHeader(label:'Best For'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _enrichment!.bestFor!,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ] else if (_enrichmentError != null)
                    // Fallback: show Serper extensions if any
                    if (product.extensions.isNotEmpty) ...[
                      const _SectionHeader(label:'Specifications'),
                      const SizedBox(height: 10),
                      ...product.extensions.map((ext) =>
                          _LegacySpecRow(spec: ext)),
                    ],

                  // ── Customer Review Analysis ─────────────────────────────
                  Divider(
                    color: isDark ? Colors.white12 : AppTheme.surfaceBorderLight,
                    height: 40,
                  ),
                  const _SectionHeader(label:'Customer Review Analysis'),
                  const SizedBox(height: 14),

                  if (!_reviewsLoaded && !_isLoadingReviews)
                    // CTA button — reviews load on demand to keep screen fast
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: BorderSide(
                            color: AppTheme.primary.withValues(alpha: 0.6)),
                        foregroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.analytics_outlined, size: 18),
                      label: const Text('Analyze Customer Reviews'),
                      onPressed: _loadReviews,
                    )
                  else if (_isLoadingReviews)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(
                              'Searching reviews across the web…',
                              style: TextStyle(
                                  color: isDark ? Colors.white38 : AppTheme.onSurfaceLowLight,
                                  fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Reddit · Amazon · CNET · Trustpilot',
                              style: TextStyle(
                                  color: isDark ? Colors.white24 : AppTheme.surfaceBorderLight,
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_reviews != null)
                    _ReviewSection(result: _reviews!)
                  else if (_reviewsError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Could not load reviews. Please try again.',
                        style: TextStyle(
                            color: isDark ? Colors.white38 : AppTheme.onSurfaceLowLight,
                            fontSize: 13),
                      ),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── Bottom CTA ──────────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text(
              'Visit Website',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            onPressed: product.link != null ? _visitWebsite : null,
          ),
        ),
      ),
    );
  }

  String _shortenUrl(String url) {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  final String? url;
  const _HeroImage({this.url});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final w = MediaQuery.sizeOf(context).width;
    return Container(
      width: double.infinity,
      height: w * 0.75,
      color: cs.surface,
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.contain,
              placeholder: (_, __) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (_, __, ___) => Center(
                child: Icon(Icons.image_not_supported_outlined,
                    size: 64,
                    color: isDark ? Colors.white24 : AppTheme.surfaceBorderLight),
              ),
            )
          : const Center(
              child: Icon(Icons.shopping_bag_outlined,
                  size: 80, color: AppTheme.primary),
            ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final double rating;
  final int? count;
  const _RatingRow({required this.rating, this.count});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        ...List.generate(5, (i) {
          if (i < rating.floor()) {
            return const Icon(Icons.star, size: 20, color: Colors.amber);
          } else if (i < rating) {
            return const Icon(Icons.star_half, size: 20, color: Colors.amber);
          }
          return const Icon(Icons.star_border, size: 20, color: Colors.amber);
        }),
        const SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
              color: isDark ? Colors.white70 : AppTheme.onSurfaceLight,
              fontSize: 14,
              fontWeight: FontWeight.w600),
        ),
        if (count != null) ...[
          const SizedBox(width: 4),
          Text(
            '($count reviews)',
            style: TextStyle(
                color: isDark ? Colors.white38 : AppTheme.onSurfaceLowLight,
                fontSize: 13),
          ),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SavingsBadge extends StatelessWidget {
  final String current;
  final String original;
  const _SavingsBadge({required this.current, required this.original});

  @override
  Widget build(BuildContext context) {
    try {
      final cur = double.parse(current.replaceAll(RegExp(r'[^\d.]'), ''));
      final orig = double.parse(original.replaceAll(RegExp(r'[^\d.]'), ''));
      if (orig > cur && cur > 0) {
        final pct = ((orig - cur) / orig * 100).round();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '-$pct%',
            style: const TextStyle(
                color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        );
      }
    } catch (_) {}
    return const SizedBox.shrink();
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: isDark ? Colors.white38 : AppTheme.onSurfaceLowLight,
                        fontSize: 11)),
                Text(value,
                    style: TextStyle(
                        color: cs.onSurface, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;
  const _FeatureRow({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.check_circle_outline,
                size: 15, color: AppTheme.accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: cs.onSurface, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final ProductSpec spec;
  const _SpecRow({required this.spec});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.tagChipBg : AppTheme.tagChipBgLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              spec.key,
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              spec.value,
              style: TextStyle(color: cs.onSurface, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fallback spec row for raw "Key: Value" Serper extension strings
class _LegacySpecRow extends StatelessWidget {
  final String spec;
  const _LegacySpecRow({required this.spec});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final colonIdx = spec.indexOf(':');
    final label = colonIdx > 0 ? spec.substring(0, colonIdx).trim() : null;
    final value = colonIdx > 0 ? spec.substring(colonIdx + 1).trim() : spec;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.tagChipBg : AppTheme.tagChipBgLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: cs.onSurface, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Review section widgets ───────────────────────────────────────────────────

class _ReviewSection extends StatelessWidget {
  final ProductReviewResult result;
  const _ReviewSection({required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final a = result.analysis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── AI Rating + Sentiment chip ───────────────────────────────────
        Row(
          children: [
            if (a.aiRating != null) ...[
              ...List.generate(5, (i) {
                if (i < a.aiRating!.floor()) {
                  return const Icon(Icons.star, size: 22, color: Colors.amber);
                } else if (i < a.aiRating!) {
                  return const Icon(Icons.star_half, size: 22, color: Colors.amber);
                }
                return const Icon(Icons.star_border, size: 22, color: Colors.amber);
              }),
              const SizedBox(width: 8),
              Text(
                a.aiRating!.toStringAsFixed(1),
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface),
              ),
              const SizedBox(width: 4),
              Text('/5  AI',
                  style: TextStyle(
                      color: isDark ? Colors.white38 : AppTheme.onSurfaceLowLight,
                      fontSize: 12)),
              const Spacer(),
            ],
            _SentimentChip(label: a.sentimentLabel),
          ],
        ),

        // ── Satisfaction bar ─────────────────────────────────────────────
        if (a.satisfactionPercent != null) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Text('Buyer satisfaction',
                  style: TextStyle(
                      color: isDark ? Colors.white54 : AppTheme.onSurfaceMidLight,
                      fontSize: 12)),
              const Spacer(),
              Text('${a.satisfactionPercent}%',
                  style: TextStyle(
                      color: _satisfactionColor(a.satisfactionPercent!),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: a.satisfactionPercent! / 100,
              minHeight: 8,
              backgroundColor: isDark
                  ? Colors.white10
                  : AppTheme.surfaceBorderLight.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(
                  _satisfactionColor(a.satisfactionPercent!)),
            ),
          ),
        ],

        const SizedBox(height: 18),

        // ── Summary ──────────────────────────────────────────────────────
        if (a.summary.isNotEmpty)
          Text(
            a.summary,
            style: TextStyle(
                color: isDark ? Colors.white70 : AppTheme.onSurfaceLight,
                fontSize: 13,
                height: 1.5),
          ),

        const SizedBox(height: 18),

        // ── Pros / Cons side by side ─────────────────────────────────────
        if (a.pros.isNotEmpty || a.cons.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (a.pros.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.thumb_up_outlined,
                            size: 14, color: Colors.greenAccent),
                        SizedBox(width: 5),
                        Text('Pros',
                            style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 8),
                      ...a.pros.map((p) => _ProsConsRow(text: p, isPositive: true)),
                    ],
                  ),
                ),
              if (a.pros.isNotEmpty && a.cons.isNotEmpty)
                const SizedBox(width: 12),
              if (a.cons.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.thumb_down_outlined,
                            size: 14, color: Colors.redAccent),
                        SizedBox(width: 5),
                        Text('Cons',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 8),
                      ...a.cons.map((c) => _ProsConsRow(text: c, isPositive: false)),
                    ],
                  ),
                ),
            ],
          ),

        const SizedBox(height: 18),

        // ── Verdict box ──────────────────────────────────────────────────
        if (a.verdict.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.15),
                  AppTheme.accent.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.verified_outlined,
                      size: 15, color: AppTheme.accent),
                  SizedBox(width: 6),
                  Text('Go4 AI Verdict',
                      style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4)),
                ]),
                const SizedBox(height: 6),
                Text(
                  a.verdict,
                  style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.4),
                ),
              ],
            ),
          ),

        // ── Source snippets ──────────────────────────────────────────────
        if (result.snippets.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Source Reviews',
              style: TextStyle(
                  color: isDark ? Colors.white54 : AppTheme.onSurfaceMidLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),
          ...result.snippets.take(6).map((s) => _SnippetCard(snippet: s)),
        ],
      ],
    );
  }

  Color _satisfactionColor(int pct) {
    if (pct >= 75) return Colors.greenAccent;
    if (pct >= 50) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}

class _SentimentChip extends StatelessWidget {
  final String label;
  const _SentimentChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (label) {
      'Highly Positive'  => Colors.greenAccent,
      'Mostly Positive'  => Colors.lightGreenAccent,
      'Mostly Negative'  => Colors.orangeAccent,
      'Highly Negative'  => Colors.redAccent,
      _                  => isDark ? Colors.white54 : AppTheme.onSurfaceMidLight,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _ProsConsRow extends StatelessWidget {
  final String text;
  final bool isPositive;
  const _ProsConsRow({required this.text, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isPositive ? Colors.greenAccent : Colors.redAccent;
    final icon  = isPositive
        ? Icons.add_circle_outline
        : Icons.remove_circle_outline;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: isDark ? Colors.white70 : AppTheme.onSurfaceLight,
                    fontSize: 12,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _SnippetCard extends StatelessWidget {
  final ReviewSnippet snippet;
  const _SnippetCard({required this.snippet});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.tagChipBg : AppTheme.tagChipBgLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.language, size: 12, color: AppTheme.primary),
              const SizedBox(width: 5),
              Text(snippet.source,
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          if (snippet.title.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(snippet.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
          if (snippet.snippet.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(snippet.snippet,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: isDark ? Colors.white54 : AppTheme.onSurfaceMidLight,
                    fontSize: 12,
                    height: 1.4)),
          ],
        ],
      ),
    );
  }
}
