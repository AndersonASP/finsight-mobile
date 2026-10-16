import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// What the second column of the Saldos table currently shows. `todas`
/// expands into all five rows; any other value shows just that one.
enum SaldosColumnFilter { todas, entrada, saida, diario, economia, cartao }

extension SaldosColumnFilterX on SaldosColumnFilter {
  String get label => switch (this) {
    SaldosColumnFilter.todas => 'todas',
    SaldosColumnFilter.entrada => 'entradas',
    SaldosColumnFilter.saida => 'saídas',
    SaldosColumnFilter.diario => 'diário',
    SaldosColumnFilter.economia => 'economia',
    SaldosColumnFilter.cartao => 'gastos com cartão',
  };

  Color get color => switch (this) {
    SaldosColumnFilter.todas => Colors.grey,
    SaldosColumnFilter.entrada => AppColors.entrada,
    SaldosColumnFilter.saida => AppColors.saida,
    SaldosColumnFilter.diario => AppColors.diario,
    SaldosColumnFilter.economia => AppColors.economia,
    SaldosColumnFilter.cartao => AppColors.cartao,
  };

  IconData get icon => switch (this) {
    SaldosColumnFilter.todas => Icons.apps_rounded,
    SaldosColumnFilter.entrada => Icons.south_west_rounded,
    SaldosColumnFilter.saida => Icons.north_east_rounded,
    SaldosColumnFilter.diario => Icons.shopping_bag_outlined,
    SaldosColumnFilter.economia => Icons.savings_outlined,
    SaldosColumnFilter.cartao => Icons.credit_card,
  };
}
