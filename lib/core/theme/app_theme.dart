import 'package:flutter/material.dart';

/// Builds the light/dark `ThemeData`. Each `ColorScheme` starts from
/// `ColorScheme.fromSeed` (so unlisted roles like containers/inverse colors
/// stay Material 3-consistent) and then pins the roles the design calls out
/// explicitly, so the brand green and the fintech-neutral surfaces don't
/// drift if the seed algorithm changes.
class AppTheme {
  AppTheme._();

  static const _brandGreen = Color(0xFF2E8B57);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(seedColor: _brandGreen).copyWith(
      primary: _brandGreen,
      onPrimary: const Color(0xFFFFFFFF),
      secondary: const Color(0xFF6B7280),
      onSecondary: const Color(0xFFFFFFFF),
      tertiary: const Color(0xFF8B5CF6),
      error: const Color(0xFFDC4545),
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF18212F),
      // Unpinned, this derives a faint green tint from the seed — overridden
      // to plain white since it backs both the Saldos header row and every
      // modal bottom sheet's default background.
      surfaceContainerLow: const Color(0xFFFFFFFF),
      surfaceContainer: const Color(0xFFF1F3F5),
      onSurfaceVariant: const Color(0xFF6B7280),
      outline: const Color(0xFFD1D5DB),
      outlineVariant: const Color(0xFFE5E7EB),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      // A hair darker than `surface` so cards and dialogs stand out from the
      // page behind them without resorting to shadows.
      scaffoldBackgroundColor: const Color(0xFFF5F6F8),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: _brandGreen,
          brightness: Brightness.dark,
        ).copyWith(
          primary: _brandGreen,
          onPrimary: const Color(0xFFFFFFFF),
          secondary: const Color(0xFFA3A3A3),
          onSecondary: const Color(0xFF171717),
          tertiary: const Color(0xFFA78BFA),
          error: const Color(0xFFF87171),
          surface: const Color(0xFF0F172A),
          onSurface: const Color(0xFFF8FAFC),
          // Same value as surfaceContainer — keeps the Saldos header row and
          // modal bottom sheets visually consistent with cards in dark mode too.
          surfaceContainerLow: const Color(0xFF1E293B),
          surfaceContainer: const Color(0xFF1E293B),
          onSurfaceVariant: const Color(0xFF94A3B8),
          outline: const Color(0xFF334155),
          outlineVariant: const Color(0xFF334155),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      // Darker than `surface`, never pure black, so elevated cards read as
      // lighter rather than as glowing panels on a flat void.
      scaffoldBackgroundColor: const Color(0xFF0B1220),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
    );
  }
}
