/// What a bill is, as far as the paid check is concerned: it decides which
/// endpoint toggles it (`/transactions/:id/paid` vs `/invoices/:id/paid`).
enum BillKind {
  recurringSaida('recurring_saida', 'transactions'),
  invoice('invoice', 'invoices');

  const BillKind(this.apiValue, this.resource);

  final String apiValue;
  final String resource;

  static BillKind fromApi(String value) =>
      values.firstWhere((k) => k.apiValue == value);
}

/// One entry of "Contas a pagar": a fixed (recurring) saída or a card invoice.
///
/// [paid] is a purely visual check — it never affects any saldo.
class Bill {
  const Bill({
    required this.kind,
    required this.id,
    required this.description,
    required this.amount,
    required this.dueDate,
    required this.paid,
  });

  final BillKind kind;
  final String id;
  final String description;
  final String amount;

  /// Local calendar date (no time) the bill is due.
  final DateTime dueDate;
  final bool paid;

  Bill copyWith({bool? paid}) => Bill(
    kind: kind,
    id: id,
    description: description,
    amount: amount,
    dueDate: dueDate,
    paid: paid ?? this.paid,
  );

  factory Bill.fromJson(Map<String, dynamic> json) {
    // `dueDate` comes as a UTC-midnight timestamp; only the calendar day matters.
    final raw = DateTime.parse(json['dueDate'] as String);
    return Bill(
      kind: BillKind.fromApi(json['kind'] as String),
      id: json['id'] as String,
      description: json['description'] as String,
      amount: json['amount'] as String,
      dueDate: DateTime(raw.year, raw.month, raw.day),
      paid: json['paid'] as bool,
    );
  }
}
