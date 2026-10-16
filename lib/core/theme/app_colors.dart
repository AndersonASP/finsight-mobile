import 'package:flutter/material.dart';

/// Fixed semantic colors per lançamento type (entrada/saída/diário/economia/
/// cartão) and the "saldos" health tiers. Toned down from the original
/// reference-app palette to read as moderate accents rather than saturated
/// fills — see small usages (icons, chips, badge text) across the features.
class AppColors {
  AppColors._();

  static const entrada = Color(0xFF2E8B57); // verde
  static const saida = Color(0xFFD2531E); // laranja queimado
  static const diario = Color(0xFFD9467A); // rosa
  static const economia = Color(0xFF65A844); // verde suave
  static const cartao = Color(0xFF7C5CE7); // roxo

  static const deficit = Color(0xFFD2531E);
  static const surplus = Color(0xFF2E8B57);

  // Status de meta de economia (abaixo / dentro / acima da faixa fixa de 20-30%).
  static const metaAbaixo = deficit;
  static const metaDentro = surplus;
  static const metaAcima = Color(0xFF2F6FB0); // azul

  // "saldos" column background tiers, from healthiest to worst. These are
  // point indicators for a single column, not full-surface fills, so they
  // stay this saturated in light mode.
  static const saldoStrongGreen = Color(0xFF1F7A3F);
  static const saldoLightGreen = Color(0xFFBFE8C9);
  static const saldoYellow = Color(0xFFF2E3A0);
  static const saldoLightRed = Color(0xFFF4C7C3);
  static const saldoDarkRed = Color(0xFFB83A3A);

  // Dark-theme backgrounds for the three middle tiers — muted so they don't
  // read as bright pastel patches against a dark surface. The corresponding
  // light-mode background above doubles as that tier's text color on these
  // (see SaldoTiers.textFor), so no separate "light text" constants here.
  static const saldoLightGreenDark = Color(0xFF1E4D34);
  static const saldoYellowDark = Color(0xFF4A3B12);
  static const saldoLightRedDark = Color(0xFF4A1F1D);
}
