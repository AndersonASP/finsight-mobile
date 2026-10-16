import 'package:flutter/material.dart';
import 'saldos_column_filter.dart';

class InstallmentInfo {
  const InstallmentInfo({required this.sequence, required this.count});

  final int sequence;
  final int count;

  factory InstallmentInfo.fromJson(Map<String, dynamic> json) {
    return InstallmentInfo(
      sequence: json['sequence'] as int,
      count: json['count'] as int,
    );
  }
}

/// Non-null when this item is one occurrence of a recurring lançamento —
/// lets the UI offer "excluir esta" vs. "excluir esta e as futuras" instead
/// of a plain delete confirmation.
class RecurringInfo {
  const RecurringInfo({required this.seriesId, required this.occurrenceIndex});

  final String seriesId;
  final int occurrenceIndex;

  factory RecurringInfo.fromJson(Map<String, dynamic> json) {
    return RecurringInfo(
      seriesId: json['seriesId'] as String,
      occurrenceIndex: json['occurrenceIndex'] as int,
    );
  }
}

class DayDetailItem {
  const DayDetailItem({
    required this.id,
    required this.type,
    required this.description,
    required this.date,
    required this.amount,
    this.categoryName,
    this.categoryColor,
    this.installment,
    this.recurring,
  });

  final String id;
  final SaldosColumnFilter type;
  final String description;
  final DateTime date;
  final String amount;
  final String? categoryName;
  final Color? categoryColor;
  final InstallmentInfo? installment;
  final RecurringInfo? recurring;

  factory DayDetailItem.fromJson(Map<String, dynamic> json) {
    final colorHex = json['categoryColor'] as String?;
    return DayDetailItem(
      id: json['id'] as String,
      type: _typeFromApi(json['type'] as String),
      description: json['description'] as String,
      date: DateTime.parse(json['date'] as String),
      amount: json['amount'] as String,
      categoryName: json['categoryName'] as String?,
      categoryColor: colorHex == null
          ? null
          : Color(int.parse(colorHex.replaceFirst('#', '0xFF'))),
      installment: json['installment'] == null
          ? null
          : InstallmentInfo.fromJson(
              json['installment'] as Map<String, dynamic>,
            ),
      recurring: json['recurring'] == null
          ? null
          : RecurringInfo.fromJson(json['recurring'] as Map<String, dynamic>),
    );
  }
}

SaldosColumnFilter _typeFromApi(String value) => switch (value) {
  'entrada' => SaldosColumnFilter.entrada,
  'saida' => SaldosColumnFilter.saida,
  'diario' => SaldosColumnFilter.diario,
  'economia' => SaldosColumnFilter.economia,
  'cartao' => SaldosColumnFilter.cartao,
  _ => throw ArgumentError('Unknown day detail item type: $value'),
};
