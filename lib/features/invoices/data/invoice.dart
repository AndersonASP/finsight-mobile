import 'package:intl/intl.dart';

enum InvoiceStatus { open, closed }

extension InvoiceStatusX on InvoiceStatus {
  String get label => switch (this) {
    InvoiceStatus.open => 'Aberta',
    InvoiceStatus.closed => 'Fechada',
  };

  static InvoiceStatus fromApi(String value) => switch (value) {
    'open' => InvoiceStatus.open,
    'closed' => InvoiceStatus.closed,
    _ => throw ArgumentError('Unknown invoice status: $value'),
  };
}

class Invoice {
  const Invoice({
    required this.id,
    required this.cardId,
    required this.periodYear,
    required this.periodMonth,
    required this.closingDate,
    required this.dueDate,
    required this.status,
    required this.total,
  });

  final String id;
  final String cardId;
  final int periodYear;
  final int periodMonth;
  final DateTime closingDate;
  final DateTime dueDate;
  final InvoiceStatus status;
  final String total;

  /// "Dezembro" — the reference month's name (`periodMonth`).
  String get monthName {
    final name = DateFormat.MMMM('pt_BR').format(DateTime(2000, periodMonth));
    return name[0].toUpperCase() + name.substring(1);
  }

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] as String,
      cardId: json['cardId'] as String,
      periodYear: json['periodYear'] as int,
      periodMonth: json['periodMonth'] as int,
      closingDate: DateTime.parse(json['closingDate'] as String),
      dueDate: DateTime.parse(json['dueDate'] as String),
      status: InvoiceStatusX.fromApi(json['status'] as String),
      total: json['total'] as String,
    );
  }
}

class InstallmentLine {
  const InstallmentLine({
    required this.id,
    required this.sequence,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.purchaseDescription,
  });

  final String id;
  final int sequence;
  final String amount;
  final DateTime dueDate;
  final String status;
  final String purchaseDescription;

  factory InstallmentLine.fromJson(Map<String, dynamic> json) {
    return InstallmentLine(
      id: json['id'] as String,
      sequence: json['sequence'] as int,
      amount: json['amount'] as String,
      dueDate: DateTime.parse(json['dueDate'] as String),
      status: json['status'] as String,
      purchaseDescription:
          (json['purchase'] as Map<String, dynamic>)['description'] as String,
    );
  }
}

class InvoiceDetail {
  const InvoiceDetail({required this.invoice, required this.installments});

  final Invoice invoice;
  final List<InstallmentLine> installments;

  factory InvoiceDetail.fromJson(Map<String, dynamic> json) {
    return InvoiceDetail(
      invoice: Invoice.fromJson(json),
      installments: (json['installments'] as List)
          .map((i) => InstallmentLine.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}
