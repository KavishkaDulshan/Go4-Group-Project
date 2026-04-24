import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and exposes the current [ThemeMode] (dark / light).
///
/// Stored in SharedPreferences under [_kThemeKey].
/// Defaults to [ThemeMode.dark] on first launch.
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>(
  (ref) => ThemeNotifier(),
);

class ThemeNotifier extends StateNotifier<ThemeMode> {
  static const _kThemeKey = 'pref_theme_mode';

  ThemeNotifier() : super(ThemeMode.dark) {
    _restore();
  }

  /// Toggle between dark and light and persist the selection.
  Future<void> toggle() async {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kThemeKey, state == ThemeMode.dark ? 'dark' : 'light');
  }

  bool get isDark => state == ThemeMode.dark;

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(_kThemeKey);
      if (val == 'light') state = ThemeMode.light;
    } catch (_) {
      // Keep default (dark) if SharedPreferences fails
    }
  }
}
