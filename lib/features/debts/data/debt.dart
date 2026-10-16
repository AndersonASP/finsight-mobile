enum DebtType { consignado, emprestimoPessoal, cartaoVencido, outro }

extension DebtTypeX on DebtType {
  String get apiValue => switch (this) {
    DebtType.consignado => 'consignado',
    DebtType.emprestimoPessoal => 'emprestimo_pessoal',
    DebtType.cartaoVencido => 'cartao_vencido',
    DebtType.outro => 'outro',
  };

  String get label => switch (this) {
    DebtType.consignado => 'Consignado',
    DebtType.emprestimoPessoal => 'Empréstimo pessoal',
    DebtType.cartaoVencido => 'Cartão vencido',
    DebtType.outro => 'Outro',
  };

  static DebtType fromApi(String value) => switch (value) {
    'consignado' => DebtType.consignado,
    'emprestimo_pessoal' => DebtType.emprestimoPessoal,
    'cartao_vencido' => DebtType.cartaoVencido,
    'outro' => DebtType.outro,
    _ => throw ArgumentError('Unknown debt type: $value'),
  };
}

enum DebtStatus { emDia, vencida, negociada, paga }

extension DebtStatusX on DebtStatus {
  String get apiValue => switch (this) {
    DebtStatus.emDia => 'em_dia',
    DebtStatus.vencida => 'vencida',
    DebtStatus.negociada => 'negociada',
    DebtStatus.paga => 'paga',
  };

  String get label => switch (this) {
    DebtStatus.emDia => 'Em dia',
    DebtStatus.vencida => 'Vencida',
    DebtStatus.negociada => 'Negociada',
    DebtStatus.paga => 'Paga',
  };

  static DebtStatus fromApi(String value) => switch (value) {
    'em_dia' => DebtStatus.emDia,
    'vencida' => DebtStatus.vencida,
    'negociada' => DebtStatus.negociada,
    'paga' => DebtStatus.paga,
    _ => throw ArgumentError('Unknown debt status: $value'),
  };
}

class Debt {
  const Debt({
    required this.id,
    required this.creditor,
    required this.type,
    required this.status,
    required this.currentBalance,
    this.originalAmount,
    this.installmentAmount,
    this.installmentDueDay,
    this.installmentsTotal,
    required this.installmentsPaid,
    this.notes,
  });

  final String id;
  final String creditor;
  final DebtType type;
  final DebtStatus status;
  final String currentBalance;
  final String? originalAmount;
  final String? installmentAmount;
  final int? installmentDueDay;
  final int? installmentsTotal;
  final int installmentsPaid;
  final String? notes;

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: json['id'] as String,
      creditor: json['creditor'] as String,
      type: DebtTypeX.fromApi(json['type'] as String),
      status: DebtStatusX.fromApi(json['status'] as String),
      currentBalance: json['currentBalance'] as String,
      originalAmount: json['originalAmount'] as String?,
      installmentAmount: json['installmentAmount'] as String?,
      installmentDueDay: json['installmentDueDay'] as int?,
      installmentsTotal: json['installmentsTotal'] as int?,
      installmentsPaid: json['installmentsPaid'] as int,
      notes: json['notes'] as String?,
    );
  }
}

class DebtPayment {
  const DebtPayment({
    required this.id,
    required this.paymentDate,
    required this.amount,
    required this.balanceAfter,
    this.notes,
  });

  final String id;
  final DateTime paymentDate;
  final String amount;
  final String balanceAfter;
  final String? notes;

  factory DebtPayment.fromJson(Map<String, dynamic> json) {
    return DebtPayment(
      id: json['id'] as String,
      paymentDate: DateTime.parse(json['paymentDate'] as String),
      amount: json['amount'] as String,
      balanceAfter: json['balanceAfter'] as String,
      notes: json['notes'] as String?,
    );
  }
}

class DebtDetail {
  const DebtDetail({required this.debt, required this.payments});

  final Debt debt;
  final List<DebtPayment> payments;

  factory DebtDetail.fromJson(Map<String, dynamic> json) {
    return DebtDetail(
      debt: Debt.fromJson(json['debt'] as Map<String, dynamic>),
      payments: (json['payments'] as List)
          .map((p) => DebtPayment.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}
