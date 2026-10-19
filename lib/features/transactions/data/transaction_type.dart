import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum FinTransactionType { entrada, saida, diario, economia, transferencia }

extension FinTransactionTypeX on FinTransactionType {
  String get apiValue => switch (this) {
    FinTransactionType.entrada => 'entrada',
    FinTransactionType.saida => 'saida',
    FinTransactionType.diario => 'diario',
    FinTransactionType.economia => 'economia',
    FinTransactionType.transferencia => 'transferencia',
  };

  String get label => switch (this) {
    FinTransactionType.entrada => 'Entrada',
    FinTransactionType.saida => 'Saída',
    FinTransactionType.diario => 'Diário',
    FinTransactionType.economia => 'Economia',
    FinTransactionType.transferencia => 'Transferência',
  };

  String get hint => switch (this) {
    FinTransactionType.entrada => 'salário, comissão, vales',
    FinTransactionType.saida => 'gastos fixos, boletos, aluguel',
    FinTransactionType.diario => 'gastos variáveis, compras',
    FinTransactionType.economia => 'guardar na reserva ou num investimento',
    FinTransactionType.transferencia =>
      'resgate da reserva, mover entre suas contas',
  };

  Color get color => switch (this) {
    FinTransactionType.entrada => AppColors.entrada,
    FinTransactionType.saida => AppColors.saida,
    FinTransactionType.diario => AppColors.diario,
    FinTransactionType.economia => AppColors.economia,
    FinTransactionType.transferencia => AppColors.transferencia,
  };

  IconData get icon => switch (this) {
    FinTransactionType.entrada => Icons.south_west_rounded,
    FinTransactionType.saida => Icons.north_east_rounded,
    FinTransactionType.diario => Icons.shopping_bag_outlined,
    FinTransactionType.economia => Icons.savings_outlined,
    FinTransactionType.transferencia => Icons.sync_alt,
  };

  /// Moves money between two of the user's own accounts — always needs a
  /// destination (`counterpartAccountId`).
  bool get isTransfer =>
      this == FinTransactionType.economia ||
      this == FinTransactionType.transferencia;

  static FinTransactionType fromApi(String value) => switch (value) {
    'entrada' => FinTransactionType.entrada,
    'saida' => FinTransactionType.saida,
    'diario' => FinTransactionType.diario,
    'economia' => FinTransactionType.economia,
    'transferencia' => FinTransactionType.transferencia,
    _ => throw ArgumentError('Unknown transaction type: $value'),
  };
}
