import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum FinTransactionType { entrada, saida, diario, economia }

extension FinTransactionTypeX on FinTransactionType {
  String get apiValue => switch (this) {
    FinTransactionType.entrada => 'entrada',
    FinTransactionType.saida => 'saida',
    FinTransactionType.diario => 'diario',
    FinTransactionType.economia => 'economia',
  };

  String get label => switch (this) {
    FinTransactionType.entrada => 'Entrada',
    FinTransactionType.saida => 'Saída',
    FinTransactionType.diario => 'Diário',
    FinTransactionType.economia => 'Economia',
  };

  String get hint => switch (this) {
    FinTransactionType.entrada => 'salário, comissão, vales',
    FinTransactionType.saida => 'gastos fixos, boletos, aluguel',
    FinTransactionType.diario => 'gastos variáveis, compras',
    FinTransactionType.economia => 'reserva, investimento',
  };

  Color get color => switch (this) {
    FinTransactionType.entrada => AppColors.entrada,
    FinTransactionType.saida => AppColors.saida,
    FinTransactionType.diario => AppColors.diario,
    FinTransactionType.economia => AppColors.economia,
  };

  IconData get icon => switch (this) {
    FinTransactionType.entrada => Icons.south_west_rounded,
    FinTransactionType.saida => Icons.north_east_rounded,
    FinTransactionType.diario => Icons.shopping_bag_outlined,
    FinTransactionType.economia => Icons.savings_outlined,
  };

  static FinTransactionType fromApi(String value) => switch (value) {
    'entrada' => FinTransactionType.entrada,
    'saida' => FinTransactionType.saida,
    'diario' => FinTransactionType.diario,
    'economia' => FinTransactionType.economia,
    _ => throw ArgumentError('Unknown transaction type: $value'),
  };
}
