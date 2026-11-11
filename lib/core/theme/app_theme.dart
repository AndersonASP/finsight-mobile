import 'package:flutter/material.dart';

/// Builds the light/dark `ThemeData`. Each `ColorScheme` starts from
/// `ColorScheme.fromSeed` (so unlisted roles like containers/inverse colors
/// stay Material 3-consistent) and then pins the roles the design calls out
/// explicitly, so the brand green and the fintech-neutral surfaces don't
/// drift if the seed algorithm changes.
///
/// On top of the color scheme, [_build] restyles the components that give
/// away the stock Material look (ripples, outlined cards, underlined inputs,
/// square buttons, plain sheets) so the whole app reads as one softer,
/// quieter system.
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
    return _build(
      colorScheme,
      scaffold: const Color(0xFFF5F6F8),
      card: colorScheme.surface,
      field: const Color(0xFFF1F3F5),
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
    // Darker than `surface`, never pure black, so elevated cards read as
    // lighter rather than as glowing panels on a flat void.
    return _build(
      colorScheme,
      scaffold: const Color(0xFF0B1220),
      card: colorScheme.surfaceContainer,
      field: const Color(0xFF0F172A),
    );
  }

  static ThemeData _build(
    ColorScheme colorScheme, {
    required Color scaffold,
    required Color card,
    required Color field,
  }) {
    final radius12 = BorderRadius.circular(12);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    const buttonText = TextStyle(fontWeight: FontWeight.w600, fontSize: 15);
    const buttonSize = Size(64, 48);

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffold,
      // The Material ink ripple is the loudest "stock Android" tell.
      splashFactory: NoSplash.splashFactory,
      highlightColor: colorScheme.onSurface.withValues(alpha: 0.05),
      // No Material 3 tint when content scrolls under the app bar: the top
      // keeps the same color while scrolling.
      appBarTheme: AppBarTheme(
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: scaffold,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      // Surfaces separate by tone, not by outline: softer and less "form".
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 0.5,
        space: 0.5,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 13,
          height: 1.3,
        ),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: buttonText,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: buttonText,
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: buttonShape, textStyle: buttonText),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius12),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
      ),
    );
  }
}

/// Text helpers shared by the money-heavy screens.
class AppText {
  AppText._();

  /// Fixed-width digits so columns of values line up and don't jitter.
  static const tabularFigures = [FontFeature.tabularFigures()];

  /// Small, quiet, upper-case label that sits above a figure.
  static TextStyle? eyebrow(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
      );
}
