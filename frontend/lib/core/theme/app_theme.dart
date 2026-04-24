import 'package:flutter/material.dart';

/// GO4 Design System
///
/// Dark theme  — Forest-green on near-black (GitHub-inspired)
/// Light theme — Pure monochromatic: black / white / shades of gray
///               No hue variation; depth comes from value contrast only.
class AppTheme {
  const AppTheme._();

  // ── Dark theme core colours ───────────────────────────────────────────────
  static const Color primary      = Color(0xFF2DA44E); // forest green
  static const Color primaryLight = Color(0xFF3FB465); // lighter green
  static const Color background   = Color(0xFF0D1117); // near-black
  static const Color surface      = Color(0xFF161B22); // dark card
  static const Color surfaceHigh  = Color(0xFF21262D); // elevated card
  static const Color surfaceBorder= Color(0xFF30363D); // subtle borders
  static const Color onSurface    = Color(0xFFE6EDF3); // near-white text
  static const Color onSurfaceMid = Color(0xFF8B949E); // muted text
  static const Color accent       = Color(0xFFE8912D); // warm amber (prices)
  static const Color accentLight  = Color(0xFFF0A732); // brighter amber
  static const Color tagChipBg    = Color(0xFF2D333B); // chip background
  static const Color error        = Color(0xFFF85149); // soft red

  // ── Light theme — monochromatic palette ───────────────────────────────────
  //    Value scale: white → light gray → mid gray → dark gray → near-black
  static const Color backgroundLight    = Color(0xFFF8F8F8); // page bg
  static const Color surfaceLight       = Color(0xFFFFFFFF); // card bg
  static const Color surfaceHighLight   = Color(0xFFEFEFEF); // inputs / raised
  static const Color surfaceBorderLight = Color(0xFFDEDEDE); // borders
  static const Color onSurfaceLight     = Color(0xFF111111); // primary text
  static const Color onSurfaceMidLight  = Color(0xFF6B6B6B); // secondary text
  static const Color onSurfaceLowLight  = Color(0xFF9E9E9E); // placeholder
  static const Color tagChipBgLight     = Color(0xFFEBEBEB); // chip background
  static const Color monoInk            = Color(0xFF111111); // buttons, links

  // ── Semantic colours (shared) ─────────────────────────────────────────────
  static const Color success = Color(0xFF3FB950);
  static const Color warning = Color(0xFFD29922);

  // ── Dark-theme gradients ──────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2DA44E), Color(0xFF1A7F37)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient subtleGradient = LinearGradient(
    colors: [Color(0xFF2DA44E), Color(0xFF3FB465)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const RadialGradient centerGlow = RadialGradient(
    colors: [Color(0x282DA44E), Color(0x000D1117)],
    radius: 0.7,
  );

  // ── Light-theme gradient (monochromatic) ──────────────────────────────────
  static const LinearGradient monoGradient = LinearGradient(
    colors: [Color(0xFF111111), Color(0xFF444444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Shadows ───────────────────────────────────────────────────────────────
  static List<BoxShadow> get primaryGlow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.28),
          blurRadius: 20,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get accentGlow => [
        BoxShadow(
          color: accent.withValues(alpha: 0.22),
          blurRadius: 16,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// Subtle shadow for light-theme cards (value contrast only, no colour).
  static List<BoxShadow> get lightCardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.07),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  // ── Dark theme ────────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary:   primary,
          secondary: accent,
          surface:   surface,
          onSurface: onSurface,
          error:     error,
        ),
        textTheme: const TextTheme(
          displayLarge:  TextStyle(color: onSurface, fontWeight: FontWeight.w800, letterSpacing: -1.0),
          displayMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          titleLarge:    TextStyle(color: onSurface, fontWeight: FontWeight.w700),
          titleMedium:   TextStyle(color: onSurface, fontWeight: FontWeight.w600),
          bodyLarge:     TextStyle(color: onSurface),
          bodyMedium:    TextStyle(color: onSurfaceMid),
          bodySmall:     TextStyle(color: onSurfaceMid),
          labelLarge:    TextStyle(color: onSurface, fontWeight: FontWeight.w600),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor:        background,
          elevation:              0,
          scrolledUnderElevation: 0,
          centerTitle:            true,
          titleTextStyle: TextStyle(
            fontSize:    18,
            fontWeight:  FontWeight.w700,
            color:       onSurface,
            letterSpacing: -0.2,
          ),
          iconTheme: IconThemeData(color: onSurface),
        ),
        cardTheme: CardThemeData(
          color:     surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: tagChipBg,
          labelStyle:      TextStyle(color: onSurface, fontSize: 12),
          shape:           StadiumBorder(),
          padding:         EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          side:            BorderSide.none,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled:    true,
          fillColor: surfaceHigh,
          hintStyle: const TextStyle(color: Color(0xFF484F58)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:   BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: surfaceBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: surfaceHigh,
          contentTextStyle: const TextStyle(color: onSurface),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 4,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation:       0,
            shadowColor:     Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(
              fontSize:   15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
        dividerTheme: DividerThemeData(
          color:     Colors.white.withValues(alpha: 0.07),
          thickness: 1,
          space:     1,
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: onSurface),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: surfaceHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: surfaceBorder),
          ),
          textStyle: const TextStyle(color: onSurface, fontSize: 14),
        ),
      );

  // ── Light theme — monochromatic ───────────────────────────────────────────
  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: backgroundLight,
        colorScheme: const ColorScheme.light(
          primary:    monoInk,           // near-black primary
          onPrimary:  Colors.white,
          secondary:  Color(0xFF444444), // dark gray secondary
          onSecondary: Colors.white,
          surface:    surfaceLight,
          onSurface:  onSurfaceLight,
          surfaceContainerHighest: surfaceHighLight,
          outline:    surfaceBorderLight,
          error:      error,
        ),
        // ── Typography ───────────────────────────────────────────────────────
        textTheme: const TextTheme(
          displayLarge:  TextStyle(color: onSurfaceLight, fontWeight: FontWeight.w800, letterSpacing: -1.0),
          displayMedium: TextStyle(color: onSurfaceLight, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          titleLarge:    TextStyle(color: onSurfaceLight, fontWeight: FontWeight.w700),
          titleMedium:   TextStyle(color: onSurfaceLight, fontWeight: FontWeight.w600),
          bodyLarge:     TextStyle(color: onSurfaceLight),
          bodyMedium:    TextStyle(color: onSurfaceMidLight),
          bodySmall:     TextStyle(color: onSurfaceMidLight),
          labelLarge:    TextStyle(color: onSurfaceLight, fontWeight: FontWeight.w600),
        ),
        // ── AppBar — white bg, near-black content ─────────────────────────────
        appBarTheme: const AppBarTheme(
          backgroundColor:        surfaceLight,
          elevation:              0,
          scrolledUnderElevation: 0.5,
          shadowColor:            Color(0x14000000),
          centerTitle:            true,
          titleTextStyle: TextStyle(
            fontSize:    18,
            fontWeight:  FontWeight.w700,
            color:       onSurfaceLight,
            letterSpacing: -0.2,
          ),
          iconTheme: IconThemeData(color: onSurfaceLight),
        ),
        // ── Cards — white, neutral border ─────────────────────────────────────
        cardTheme: CardThemeData(
          color:       surfaceLight,
          elevation:   0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: surfaceBorderLight),
          ),
        ),
        // ── Chips — dark label on light chip bg ──────────────────────────────
        chipTheme: const ChipThemeData(
          backgroundColor: tagChipBgLight,
          labelStyle:      TextStyle(color: onSurfaceLight, fontSize: 12, fontWeight: FontWeight.w500),
          shape:           StadiumBorder(),
          padding:         EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          side:            BorderSide(color: surfaceBorderLight),
        ),
        // ── Inputs — light gray fill, near-black focus ring ──────────────────
        inputDecorationTheme: InputDecorationTheme(
          filled:    true,
          fillColor: surfaceHighLight,
          hintStyle: const TextStyle(color: onSurfaceLowLight),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:   BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:   const BorderSide(color: surfaceBorderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:   const BorderSide(color: monoInk, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        // ── Progress — near-black ─────────────────────────────────────────────
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: monoInk),
        // ── Snack bars — near-black bg, white text (high contrast) ────────────
        snackBarTheme: SnackBarThemeData(
          backgroundColor:  const Color(0xFF1A1A1A),
          contentTextStyle: const TextStyle(color: Colors.white),
          behavior:         SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 6,
        ),
        // ── Elevated buttons — near-black bg, white label ─────────────────────
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: monoInk,
            foregroundColor: Colors.white,
            elevation:       0,
            shadowColor:     Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(
              fontSize:   15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
        // ── Outlined buttons — dark border, dark label ────────────────────────
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: monoInk,
            side: const BorderSide(color: monoInk),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        // ── Text buttons ──────────────────────────────────────────────────────
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: monoInk,
          ),
        ),
        // ── Divider ───────────────────────────────────────────────────────────
        dividerTheme: const DividerThemeData(
          color:     surfaceBorderLight,
          thickness: 1,
          space:     1,
        ),
        // ── Icon buttons ──────────────────────────────────────────────────────
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: onSurfaceLight),
        ),
        // ── Popup menus — white bg, neutral border ────────────────────────────
        popupMenuTheme: PopupMenuThemeData(
          color: surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: surfaceBorderLight),
          ),
          textStyle: const TextStyle(color: onSurfaceLight, fontSize: 14),
          elevation: 4,
          shadowColor: Colors.black26,
        ),
        // ── Bottom sheets ─────────────────────────────────────────────────────
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        // ── Dialogs ───────────────────────────────────────────────────────────
        dialogTheme: const DialogThemeData(
          backgroundColor: surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          titleTextStyle: TextStyle(
            color:      onSurfaceLight,
            fontSize:   17,
            fontWeight: FontWeight.w700,
          ),
          contentTextStyle: TextStyle(
            color:    onSurfaceMidLight,
            fontSize: 14,
          ),
        ),
      );
}
