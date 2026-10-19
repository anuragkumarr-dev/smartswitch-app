import 'package:flutter/material.dart';

/// Design tokens from blueprint §4.1.
///
/// Grid: 8 pt spacing, 16 pt screen margins.
/// Radius: 16–20 for cards, full-round for toggles.
/// Touch targets: ≥48 dp.
/// Type: Inter; title 20, body 14–16, caption 12.
/// Colour: neutral surfaces, amber accent for "on", warning for offline.
/// Full dark mode via tokens — no hard-coded colours.

// ──────────────────────────────────────────
//  Spacing tokens (8-pt grid)
// ──────────────────────────────────────────

abstract final class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Screen margin (blueprint: 16 pt).
  static const double screenMargin = 16;
}

// ──────────────────────────────────────────
//  Radius tokens
// ──────────────────────────────────────────

abstract final class Radii {
  static const double card = 16;
  static const double cardLg = 20;
  static const double button = 12;
  static const double toggle = 999; // full-round
}

// ──────────────────────────────────────────
//  Duration tokens
// ──────────────────────────────────────────

abstract final class Durations {
  /// Toggle animation: 150–200 ms, ease-out.
  static const Duration toggle = Duration(milliseconds: 180);

  /// Card press scale animation.
  static const Duration cardPress = Duration(milliseconds: 120);
}

// ──────────────────────────────────────────
//  Colour tokens
// ──────────────────────────────────────────

abstract final class AppColors {
  // ── Light ──
  static const Color lightSurface = Color(0xFFF8F8F8);
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightOnSurface = Color(0xFF1C1C1E);
  static const Color lightOnSurfaceVariant = Color(0xFF6E6E73);

  // ── Dark ──
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkOnSurface = Color(0xFFF2F2F7);
  static const Color darkOnSurfaceVariant = Color(0xFF98989F);

  // ── Shared accent & semantic ──
  static const Color accent = Color(0xFFFF9F0A); // amber "on"
  static const Color accentDim = Color(0xFFCC7F08);
  static const Color offline = Color(0xFFAEAEB2); // grey warning
  static const Color error = Color(0xFFFF3B30);
  static const Color success = Color(0xFF34C759);
}

// ──────────────────────────────────────────
//  Text theme (Inter family)
// ──────────────────────────────────────────

TextTheme _buildTextTheme(Color bodyColor) {
  return TextTheme(
    titleLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: bodyColor,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: bodyColor,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: bodyColor,
    ),
    labelSmall: TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: bodyColor,
    ),
  );
}

// ──────────────────────────────────────────
//  ThemeData builders
// ──────────────────────────────────────────

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.lightBackground,
  colorScheme: const ColorScheme.light(
    primary: AppColors.accent,
    secondary: AppColors.accentDim,
    surface: AppColors.lightSurface,
    error: AppColors.error,
    onPrimary: Colors.white,
    onSurface: AppColors.lightOnSurface,
    onSurfaceVariant: AppColors.lightOnSurfaceVariant,
  ),
  textTheme: _buildTextTheme(AppColors.lightOnSurface),
  cardTheme: CardThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.card),
    ),
    elevation: 0,
    margin: const EdgeInsets.all(Spacing.sm),
  ),
  materialTapTargetSize: MaterialTapTargetSize.padded, // ≥48 dp
);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.darkBackground,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.accent,
    secondary: AppColors.accentDim,
    surface: AppColors.darkSurface,
    error: AppColors.error,
    onPrimary: Colors.black,
    onSurface: AppColors.darkOnSurface,
    onSurfaceVariant: AppColors.darkOnSurfaceVariant,
  ),
  textTheme: _buildTextTheme(AppColors.darkOnSurface),
  cardTheme: CardThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.card),
    ),
    elevation: 0,
    margin: const EdgeInsets.all(Spacing.sm),
  ),
  materialTapTargetSize: MaterialTapTargetSize.padded,
);
