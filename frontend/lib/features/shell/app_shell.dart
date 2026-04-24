import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _tabs = [
    (path: '/',        icon: Icons.camera_alt_rounded,    outlinedIcon: Icons.camera_alt_outlined,    label: 'Scan'),
    (path: '/map',     icon: Icons.explore_rounded,       outlinedIcon: Icons.explore_outlined,       label: 'Map'),
    (path: '/history', icon: Icons.history_rounded,       outlinedIcon: Icons.history,                label: 'History'),
    (path: '/for-you', icon: Icons.auto_awesome_rounded,  outlinedIcon: Icons.auto_awesome_outlined,  label: 'For You'),
    (path: '/profile', icon: Icons.person_rounded,        outlinedIcon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final idx      = _tabs.indexWhere((t) => t.path == location);
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIdx   = _selectedIndex(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: child,
      bottomNavigationBar: _FloatingNavBar(
        selectedIndex: selectedIdx,
        bottomPadding: bottomPadding,
        onTap: (i) {
          HapticFeedback.selectionClick();
          context.go(_tabs[i].path);
        },
        tabs: _tabs,
      ),
    );
  }
}

// ─── Nav bar container ────────────────────────────────────────────────────────

class _FloatingNavBar extends StatelessWidget {
  final int    selectedIndex;
  final double bottomPadding;
  final void   Function(int) onTap;
  final List<({String path, IconData icon, IconData outlinedIcon, String label})> tabs;

  const _FloatingNavBar({
    required this.selectedIndex,
    required this.bottomPadding,
    required this.onTap,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 0.5, color: Theme.of(context).dividerColor),
          Padding(
            padding: EdgeInsets.only(
              top:    8,
              bottom: bottomPadding + 8,
              left:   4,
              right:  4,
            ),
            child: Row(
              children: List.generate(tabs.length, (i) {
                return Expanded(
                  child: GestureDetector(
                    onTap:    () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: _NavItem(
                      icon:         tabs[i].icon,
                      outlinedIcon: tabs[i].outlinedIcon,
                      label:        tabs[i].label,
                      selected:     i == selectedIndex,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Single nav item ──────────────────────────────────────────────────────────
//
// Uses a COLUMN layout (icon above, label below) — the standard BottomNavigationBar
// pattern.  This eliminates the horizontal overflow that occurred with the old
// Row layout when long labels ("History", "For You") were wider than the
// Expanded share available on narrow screens.

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData outlinedIcon;
  final String   label;
  final bool     selected;

  const _NavItem({
    required this.icon,
    required this.outlinedIcon,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final unselectedColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);

    return Column(
      mainAxisSize:      MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pill highlight around the icon
        AnimatedContainer(
          duration:    const Duration(milliseconds: 220),
          curve:       Curves.easeOutCubic,
          padding:     const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              selected ? icon : outlinedIcon,
              key:   ValueKey(selected),
              size:  22,
              color: selected ? AppTheme.primary : unselectedColor,
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Label — always visible, never overflows
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color:         selected ? AppTheme.primary : unselectedColor,
            fontSize:      10,
            fontWeight:    selected ? FontWeight.w700 : FontWeight.w400,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}
