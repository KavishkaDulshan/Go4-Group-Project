import 'package:go_router/go_router.dart';
import '../../features/home/home_screen.dart';
import '../../features/processing/processing_screen.dart';
import '../../features/filters/search_filters_screen.dart';
import '../../features/results/results_screen.dart';
import '../../features/map/map_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/product/product_detail_screen.dart';
import '../../features/wishlist/wishlist_screen.dart';
import '../../features/recommendations/recommendations_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../models/product.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // ── Shell: screens that show the bottom nav bar ──────────────────────
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/',        builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/map',     builder: (_, __) => const MapScreen()),
        GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
        GoRoute(path: '/for-you', builder: (_, __) => const RecommendationsScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ],
    ),
    // ── Full-screen routes: no bottom nav bar ────────────────────────────
    GoRoute(path: '/processing', builder: (_, __) => const ProcessingScreen()),
    GoRoute(path: '/filters',    builder: (_, __) => const SearchFiltersScreen()),
    GoRoute(path: '/results',    builder: (_, __) => const ResultsScreen()),
    GoRoute(path: '/wishlist',   builder: (_, __) => const WishlistScreen()),
    GoRoute(
      path: '/product',
      builder: (_, state) {
        final product = state.extra as Product;
        return ProductDetailScreen(product: product);
      },
    ),
  ],
);
