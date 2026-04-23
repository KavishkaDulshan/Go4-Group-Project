import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/search_filter.dart';
import '../../providers/search_provider.dart';

/// Shown between the analyze step and the product search step.
///
/// Displays AI-detected product info and lets the user refine filters
/// before tapping "Search" to get results.
class SearchFiltersScreen extends ConsumerStatefulWidget {
  const SearchFiltersScreen({super.key});

  @override
  ConsumerState<SearchFiltersScreen> createState() =>
      _SearchFiltersScreenState();
}

class _SearchFiltersScreenState extends ConsumerState<SearchFiltersScreen> {
  late List<SearchFilter> _filters;

  @override
  void initState() {
    super.initState();
    final searchState = ref.read(searchProvider);

    // Deep-copy the filters so we own the selectedValues mutations locally
    final raw = searchState.pendingFilters ?? [];
    _filters = raw
        .map((f) => SearchFilter(
              key: f.key,
              label: f.label,
              type: f.type,
              options: f.options,
              defaultValue: f.defaultValue,
              selectedValues: List<String>.from(f.selectedValues),
            ))
        .toList();
  }

  void _goSearch() {
    ref.read(searchProvider.notifier).submitWithFilters(_filters);
    context.push('/processing');
  }

  void _startOver() {
    ref.read(searchProvider.notifier).reset();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(searchProvider);
    final tags = state.analyzedTags ?? {};
    final product = tags['productName'] as String? ?? 'Product';
    final cat = tags['category'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Refine Search'),
        actions: [
          TextButton(
            onPressed: _startOver,
            child: Text('Start over',
                style: TextStyle(
                    color: isDark ? Colors.white54 : AppTheme.onSurfaceMidLight)),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ── Product identity card ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: _ProductCard(
              state: state,
              product: product,
              cat: cat,
              tags: tags,
            ),
          ),

          // ── Section label ─────────────────────────────────────────────────
          if (_filters.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text(
                  'Customize your search',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : AppTheme.onSurfaceMidLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

          // ── Filter rows ───────────────────────────────────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _FilterRow(
                filter: _filters[i],
                onChanged: (newValues) =>
                    setState(() => _filters[i].selectedValues = newValues),
              ),
              childCount: _filters.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),

      // ── Bottom CTA ────────────────────────────────────────────────────────
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
            icon: const Icon(Icons.search, size: 20),
            label: const Text(
              'Search',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            onPressed: _goSearch,
          ),
        ),
      ),
    );
  }
}

// ─── Product identity card ────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final SearchState state;
  final String product;
  final String cat;
  final Map<String, dynamic> tags;

  const _ProductCard({
    required this.state,
    required this.product,
    required this.cat,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final color = tags['color'] as String?;
    final material = tags['material'] as String?;
    final style = tags['style'] as String?;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail (from captured image if available)
          if (state.capturedImagePath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(state.capturedImagePath!),
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _imageFallback(context),
              ),
            ),
            const SizedBox(width: 14),
          ],

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: AppTheme.accent),
                    SizedBox(width: 5),
                    Text('AI Detected',
                        style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  product,
                  style: const TextStyle(
                    color: AppTheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (cat.isNotEmpty) _Chip(cat, AppTheme.primary),
                    if (color != null) _Chip(color, AppTheme.primaryLight),
                    if (material != null) _Chip(material, AppTheme.accent),
                    if (style != null) _Chip(style, AppTheme.primaryLight),
                    if (state.capturedAudioPath != null)
                      const _Chip('Voice input', AppTheme.accent),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageFallback(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.tagChipBg : AppTheme.tagChipBgLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.shopping_bag_outlined,
          size: 32, color: AppTheme.primary),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

// ─── Filter row ───────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final SearchFilter filter;

  /// Called with the full new list of selected values whenever the user
  /// makes a selection. For dropdown, this is 0 or 1 items.
  final void Function(List<String>) onChanged;

  const _FilterRow({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            filter.label,
            style: const TextStyle(
              color: AppTheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          filter.type == 'dropdown'
              ? _DropdownFilter(filter: filter, onChanged: onChanged)
              : _ChipsFilter(filter: filter, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final SearchFilter filter;
  final void Function(List<String>) onChanged;

  const _DropdownFilter({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final currentValue =
        filter.options.any((o) => o.value == filter.selectedValue)
            ? filter.selectedValue
            : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark
                ? Colors.white12
                : AppTheme.surfaceBorderLight.withValues(alpha: 0.5)),
      ),
      child: DropdownButton<String>(
        value: currentValue,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: cs.surface,
        style: const TextStyle(color: AppTheme.onSurface, fontSize: 14),
        hint: Text('Any',
            style: TextStyle(
                color: isDark ? Colors.white38 : AppTheme.onSurfaceLowLight)),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text('Any',
                style: TextStyle(
                    color:
                        isDark ? Colors.white38 : AppTheme.onSurfaceLowLight)),
          ),
          ...filter.options.map((opt) => DropdownMenuItem<String>(
                value: opt.value,
                child: Text(opt.label),
              )),
        ],
        onChanged: (val) => onChanged(val == null ? [] : [val]),
      ),
    );
  }
}

/// Multi-select chips — each chip independently toggles in/out.
class _ChipsFilter extends StatelessWidget {
  final SearchFilter filter;
  final void Function(List<String>) onChanged;

  const _ChipsFilter({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filter.options.map((opt) {
        final selected = filter.selectedValues.contains(opt.value);
        return GestureDetector(
          onTap: () {
            final updated = List<String>.from(filter.selectedValues);
            if (selected) {
              updated.remove(opt.value);
            } else {
              updated.add(opt.value);
            }
            onChanged(updated);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.2)
                  : cs.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected
                    ? AppTheme.primary
                    : (isDark ? Colors.white24 : AppTheme.surfaceBorderLight),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(
              opt.label,
              style: TextStyle(
                color: selected
                    ? AppTheme.primary
                    : (isDark ? Colors.white70 : AppTheme.onSurfaceLight),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
