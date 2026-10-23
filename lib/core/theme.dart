import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens from blueprint §4.1.
///
/// Grid: 8 pt spacing, 16 pt screen margins.
/// Radius: 16–20 for cards, full-round for toggles.
/// Touch targets: ≥48 dp.
/// Type: Inter; title 20, body 14–16, caption 12.
/// Colour: neutral surfaces, amber accent for "on", warning for offline.
/// Full dark mode via tokens — no hard-coded colours outside theme tokens.

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
  static const double sm = 8;
  static const double button = 12;
  static const double card = 16;
  static const double cardLg = 20;
  static const double toggle = 999; // full-round
}

// ──────────────────────────────────────────
//  Duration tokens
// ──────────────────────────────────────────

abstract final class AppDurations {
  /// Toggle animation: 150–200 ms, ease-out (Blueprint §4.1).
  static const Duration toggle = Duration(milliseconds: 180);

  /// Card press scale animation.
  static const Duration cardPress = Duration(milliseconds: 120);

  /// Shimmer skeleton sweep.
  static const Duration shimmer = Duration(milliseconds: 1200);

  /// Error shake duration.
  static const Duration shake = Duration(milliseconds: 400);
}

// ──────────────────────────────────────────
//  Colour tokens
// ──────────────────────────────────────────

abstract final class AppColors {
  // ── Light ──
  static const Color lightSurface = Color(0xFFF8F8F8);
  static const Color lightSurfaceCard = Color(0xFFFFFFFF);
  static const Color lightBackground = Color(0xFFF2F2F7);
  static const Color lightOnSurface = Color(0xFF1C1C1E);
  static const Color lightOnSurfaceVariant = Color(0xFF6E6E73);
  static const Color lightBorder = Color(0xFFE5E5EA);

  // ── Dark ──
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkSurfaceCard = Color(0xFF2C2C2E);
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkOnSurface = Color(0xFFF2F2F7);
  static const Color darkOnSurfaceVariant = Color(0xFF98989F);
  static const Color darkBorder = Color(0xFF38383A);

  // ── Shared accent & semantic ──
  static const Color accent = Color(0xFFFF9F0A); // amber "on" (Blueprint §4.1)
  static const Color accentDim = Color(0xFFCC7F08);
  static const Color accentGlow = Color(0x66FF9F0A);
  static const Color offline = Color(0xFFAEAEB2); // grey warning
  static const Color error = Color(0xFFFF3B30);
  static const Color success = Color(0xFF34C759);

  // ── RSSI Signal Colors (Blueprint §4.4) ──
  static const Color rssiStrong = Color(0xFF34C759); // > -60 dBm (green)
  static const Color rssiFair = Color(0xFFFF9F0A); // -60 to -75 dBm (amber)
  static const Color rssiWeak = Color(0xFFFF3B30); // < -75 dBm (red)
  static const Color rssiOffline = Color(0xFF8E8E93);
}

// ──────────────────────────────────────────
//  Shadow tokens
// ──────────────────────────────────────────

abstract final class AppShadows {
  static List<BoxShadow> glow({Color color = AppColors.accent, double blur = 16}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.35),
        blurRadius: blur,
        spreadRadius: 2,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static const List<BoxShadow> cardLight = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> cardDark = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
}

// ──────────────────────────────────────────
//  Haptic feedback helper
// ──────────────────────────────────────────

abstract final class AppHaptics {
  /// Light haptic on toggle (Blueprint §4.1).
  static Future<void> light({bool reduceMotion = false}) async {
    if (!reduceMotion) {
      await HapticFeedback.lightImpact();
    }
  }

  /// Medium haptic on long-press (Blueprint §4.1).
  static Future<void> medium({bool reduceMotion = false}) async {
    if (!reduceMotion) {
      await HapticFeedback.mediumImpact();
    }
  }

  /// Haptic for errors.
  static Future<void> error({bool reduceMotion = false}) async {
    if (!reduceMotion) {
      await HapticFeedback.heavyImpact();
    }
  }
}

// ──────────────────────────────────────────
//  Text theme (Inter family)
// ──────────────────────────────────────────

TextTheme _buildTextTheme(Color bodyColor) {
  return TextTheme(
    displayMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: bodyColor,
      letterSpacing: -0.5,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'Inter',
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: bodyColor,
    ),
    titleLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: bodyColor,
    ),
    titleMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 16,
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
    bodySmall: TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: bodyColor,
    ),
    labelLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: bodyColor,
    ),
    labelSmall: TextStyle(
      fontFamily: 'Inter',
      fontSize: 11,
      fontWeight: FontWeight.w500,
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
    color: AppColors.lightSurfaceCard,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.card),
    ),
    elevation: 0,
    margin: EdgeInsets.zero,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.lightSurfaceCard,
    selectedItemColor: AppColors.accent,
    unselectedItemColor: AppColors.lightOnSurfaceVariant,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppColors.lightSurfaceCard,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.cardLg),
    ),
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
    color: AppColors.darkSurfaceCard,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.card),
    ),
    elevation: 0,
    margin: EdgeInsets.zero,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.darkSurfaceCard,
    selectedItemColor: AppColors.accent,
    unselectedItemColor: AppColors.darkOnSurfaceVariant,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppColors.darkSurfaceCard,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.cardLg),
    ),
  ),
  materialTapTargetSize: MaterialTapTargetSize.padded,
);
