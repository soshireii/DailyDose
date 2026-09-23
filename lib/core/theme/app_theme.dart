import 'package:flutter/material.dart';

/// Brand palette. Kept as named constants so every screen (and the week
/// strip's status dots) reads colors from one place.
class AppColors {
  // Primary: light sky blue - buttons, selected states, accents.
  static const primary = Color(0xFF8ED2E8);
  static const primarySoft = Color(0xFFA6D5E5);

  // Secondary: deep navy - strong text, dark surfaces, selected day.
  static const secondary = Color(0xFF0D2647);

  // Status indicators (used consistently across the app: cards, badges,
  // the week strip dots).
  static const statusTaken = Color(0xFF2E9E5B); // green
  static const statusPending = Color(0xFFF2B134); // yellow
  static const statusMissed = Color(0xFFE0524C); // red
  static const neutralGray = Color(0xFF9AA7B4); // no doses / not scheduled
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    );
    final scheme = base.copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.secondary,
      primaryContainer: isDark ? AppColors.secondary : AppColors.primarySoft,
      onPrimaryContainer: isDark ? AppColors.primary : AppColors.secondary,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: isDark
          ? const Color(0xFF1B3A5C)
          : AppColors.primarySoft,
      onSecondaryContainer: isDark ? Colors.white : AppColors.secondary,
      surface: isDark ? const Color(0xFF0B1420) : Colors.white,
      error: AppColors.statusMissed,
    );
    final radius = BorderRadius.circular(16);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : AppColors.secondary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.secondary,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.primary : AppColors.secondary,
          side: BorderSide(
            color: isDark ? AppColors.primary : AppColors.secondary,
          ),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: AppColors.primarySoft,
      ),
    );
  }
}
