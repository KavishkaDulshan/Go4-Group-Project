import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/wishlist_provider.dart';

/// Profile / Account screen.
///
/// HCI evaluation notes:
/// · H1 Visibility of status: loading spinner shown clearly during sign-in.
/// · H4 Consistency: all action buttons have ≥ 48 dp touch targets.
/// · H7 Flexibility: signed-in users see account details + quick actions.
/// · H8 Aesthetic minimalism: single column, whitespace-driven hierarchy.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth          = ref.watch(authProvider);
    final wishlistCount = ref.watch(wishlistProvider).length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Account')),
      body: auth.isLoading
          ? const Center(child: CircularProgressIndicator())
          : auth.isSignedIn
              ? _SignedInView(auth: auth, ref: ref, wishlistCount: wishlistCount)
              : _SignedOutView(ref: ref, errorMessage: auth.errorMessage),
    );
  }
}

// ─── Signed-out view ──────────────────────────────────────────────────────────

class _SignedOutView extends StatelessWidget {
  final WidgetRef ref;
  final String?   errorMessage;

  const _SignedOutView({required this.ref, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          Container(
            width:  96,
            height: 96,
            decoration: BoxDecoration(
              color:  cs.surfaceContainerHighest,
              shape:  BoxShape.circle,
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Icon(
              Icons.person_outline_rounded,
              size:  48,
              color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Sign in to GO4',
            style: TextStyle(
              color:      cs.onSurface,
              fontSize:   22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Save your search history and\naccess it across all your devices.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:    isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
              fontSize: 14,
              height:   1.5,
            ),
          ),
          const SizedBox(height: 36),

          if (errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:  AppTheme.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppTheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: AppTheme.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon:  const Icon(Icons.login_rounded, size: 20),
              label: const Text('Continue with Google'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () => ref.read(authProvider.notifier).signIn(),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Your data is used only to power search history.\nWe never share or sell your information.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:    isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
              fontSize: 11,
              height:   1.5,
            ),
          ),

          // Theme toggle
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color:        cs.surface,
              borderRadius: BorderRadius.circular(16),
              border:       Border.all(color: Theme.of(context).dividerColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => ref.read(themeProvider.notifier).toggle(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width:  40,
                      height: 40,
                      decoration: BoxDecoration(
                        color:        AppTheme.primaryLight.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        size:  20,
                        color: AppTheme.primaryLight,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                        style: TextStyle(
                          color:      cs.onSurface,
                          fontSize:   15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Switch(
                      value:    !isDark,
                      onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
                      activeThumbColor: AppTheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

// ─── Signed-in view ───────────────────────────────────────────────────────────

class _SignedInView extends StatelessWidget {
  final AuthState auth;
  final WidgetRef ref;
  final int       wishlistCount;

  const _SignedInView({
    required this.auth,
    required this.ref,
    required this.wishlistCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;
    final user   = auth.user!;

    return Column(
      children: [
        // ── Scrollable content ──────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Header: avatar + user info
                Container(
                  width:   double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    border: Border(
                      bottom: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: cs.surfaceContainerHighest,
                            backgroundImage: user.photoUrl != null
                                ? CachedNetworkImageProvider(user.photoUrl!)
                                : null,
                            child: user.photoUrl == null
                                ? Icon(Icons.person_rounded,
                                    size:  44,
                                    color: isDark
                                        ? AppTheme.onSurfaceMid
                                        : AppTheme.onSurfaceMidLight)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right:  0,
                            child: Container(
                              width:  24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? AppTheme.background
                                      : AppTheme.backgroundLight,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size:  14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (user.displayName != null) ...[
                        Text(
                          user.displayName!,
                          style: TextStyle(
                            fontSize:   20,
                            fontWeight: FontWeight.w700,
                            color:      cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        user.email,
                        style: TextStyle(
                          color:    isDark
                              ? AppTheme.onSurfaceMid
                              : AppTheme.onSurfaceMidLight,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.40)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded,
                                size: 14, color: AppTheme.primary),
                            SizedBox(width: 6),
                            Text(
                              'Signed in with Google',
                              style: TextStyle(
                                color:      AppTheme.primary,
                                fontSize:   12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Navigation pill group
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 10),
                        child: Text(
                          'NAVIGATION',
                          style: TextStyle(
                            color:         isDark
                                ? AppTheme.onSurfaceMid
                                : AppTheme.onSurfaceMidLight,
                            fontSize:      11,
                            fontWeight:    FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),

                      // Grouped pill card
                      Container(
                        decoration: BoxDecoration(
                          color:        cs.surface,
                          borderRadius: BorderRadius.circular(16),
                          border:       Border.all(
                              color: Theme.of(context).dividerColor),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            _NavPill(
                              icon:      Icons.history_rounded,
                              iconColor: AppTheme.primaryLight,
                              label:     'Search History',
                              onTap:     () => context.go('/history'),
                            ),
                            Divider(
                                height: 1,
                                color: Theme.of(context).dividerColor),
                            _NavPill(
                              icon:      Icons.auto_awesome_rounded,
                              iconColor: AppTheme.accent,
                              label:     'For You',
                              onTap:     () => context.go('/for-you'),
                            ),
                            Divider(
                                height: 1,
                                color: Theme.of(context).dividerColor),
                            _NavPill(
                              icon:      Icons.bookmark_rounded,
                              iconColor: AppTheme.accent,
                              label:     'Saved Items',
                              badge:     wishlistCount > 0
                                  ? '$wishlistCount'
                                  : null,
                              badgeColor: AppTheme.accent,
                              onTap: () => context.push('/wishlist'),
                            ),
                            Divider(
                                height: 1,
                                color: Theme.of(context).dividerColor),

                            // Theme toggle row
                            InkWell(
                              onTap: () =>
                                  ref.read(themeProvider.notifier).toggle(),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Container(
                                      width:  40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryLight
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        isDark
                                            ? Icons.light_mode_rounded
                                            : Icons.dark_mode_rounded,
                                        size:  20,
                                        color: AppTheme.primaryLight,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        isDark
                                            ? 'Switch to Light Mode'
                                            : 'Switch to Dark Mode',
                                        style: TextStyle(
                                          color:      cs.onSurface,
                                          fontSize:   15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Switch(
                                      value:    !isDark,
                                      onChanged: (_) => ref
                                          .read(themeProvider.notifier)
                                          .toggle(),
                                      activeThumbColor: AppTheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Sign out — pinned at bottom ──────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon:  const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                minimumSize:     const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => ref.read(authProvider.notifier).signOut(),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Nav pill row ─────────────────────────────────────────────────────────────

class _NavPill extends StatelessWidget {
  final IconData     icon;
  final Color        iconColor;
  final String       label;
  final String?      badge;
  final Color?       badgeColor;
  final VoidCallback onTap;

  const _NavPill({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width:  40,
              height: 40,
              decoration: BoxDecoration(
                color:        iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color:      cs.onSurface,
                  fontSize:   15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (badgeColor ?? iconColor).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    color:      badgeColor ?? iconColor,
                    fontSize:   12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              Icons.chevron_right_rounded,
              size:  20,
              color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
            ),
          ],
        ),
      ),
    );
  }
}
