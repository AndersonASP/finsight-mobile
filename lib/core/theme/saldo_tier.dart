import 'package:flutter/material.dart';
import 'app_colors.dart';

enum SaldoTier { strongGreen, lightGreen, yellow, lightRed, darkRed }

/// Colors the "saldos" column by how healthy the balance is. Thresholds are a
/// sane personal-finance default (not derived from any user data) — adjust
/// [highThreshold]/[positiveThreshold]/[lowNegativeThreshold] to taste.
class SaldoTiers {
  SaldoTiers._();

  static const highThreshold = 2000.0;
  static const positiveThreshold = 500.0;
  static const lowNegativeThreshold = -500.0;

  static SaldoTier tierFor(double balance) {
    if (balance >= highThreshold) return SaldoTier.strongGreen;
    if (balance >= positiveThreshold) return SaldoTier.lightGreen;
    if (balance >= 0) return SaldoTier.yellow;
    if (balance >= lowNegativeThreshold) return SaldoTier.lightRed;
    return SaldoTier.darkRed;
  }

  /// Backgrounds stay deep/saturated at the extremes in both themes — those
  /// already read fine against a dark surface. The three middle tiers swap
  /// to a muted dark variant in dark mode so they don't look like bright
  /// pastel patches against a dark background.
  static Color backgroundFor(SaldoTier tier, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (tier) {
      SaldoTier.strongGreen => AppColors.saldoStrongGreen,
      SaldoTier.lightGreen =>
        dark ? AppColors.saldoLightGreenDark : AppColors.saldoLightGreen,
      SaldoTier.yellow =>
        dark ? AppColors.saldoYellowDark : AppColors.saldoYellow,
      SaldoTier.lightRed =>
        dark ? AppColors.saldoLightRedDark : AppColors.saldoLightRed,
      SaldoTier.darkRed => AppColors.saldoDarkRed,
    };
  }

  static Color textFor(SaldoTier tier, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (tier) {
      SaldoTier.strongGreen => Colors.white,
      // In dark mode the former light-mode background doubles as the light
      // accent text color on top of the new muted dark background.
      SaldoTier.lightGreen =>
        dark ? AppColors.saldoLightGreen : const Color(0xFF14432A),
      SaldoTier.yellow =>
        dark ? AppColors.saldoYellow : const Color(0xFF55480C),
      SaldoTier.lightRed =>
        dark ? AppColors.saldoLightRed : const Color(0xFF5B1F1C),
      SaldoTier.darkRed => Colors.white,
    };
  }
}
