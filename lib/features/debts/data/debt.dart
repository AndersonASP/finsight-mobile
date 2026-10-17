enum DebtType {
  consignado,
  emprestimoPessoal,
  financiamento,
  cartaoVencido,
  chequeEspecial,
  outro,
}

extension DebtTypeX on DebtType {
  String get apiValue => switch (this) {
    DebtType.consignado => 'consignado',
    DebtType.emprestimoPessoal => 'emprestimo_pessoal',
    DebtType.financiamento => 'financiamento',
    DebtType.cartaoVencido => 'cartao_vencido',
    DebtType.chequeEspecial => 'cheque_especial',
    DebtType.outro => 'outro',
  };

  String get label => switch (this) {
    DebtType.consignado => 'Consignado',
    DebtType.emprestimoPessoal => 'Empréstimo pessoal',
    DebtType.financiamento => 'Financiamento',
    DebtType.cartaoVencido => 'Cartão (rotativo / atrasado)',
    DebtType.chequeEspecial => 'Cheque especial',
    DebtType.outro => 'Outro',
  };

  static DebtType fromApi(String value) =>
      DebtType.values.firstWhere((t) => t.apiValue == value);
}

enum DebtStatus { emDia, vencida, negociada, paga }

extension DebtStatusX on DebtStatus {
  String get apiValue => switch (this) {
    DebtStatus.emDia => 'em_dia',
    DebtStatus.vencida => 'vencida',
    DebtStatus.negociada => 'negociada',
    DebtStatus.paga => 'paga',
  };

  static DebtStatus fromApi(String value) =>
      DebtStatus.values.firstWhere((s) => s.apiValue == value);
}

/// How the app knows what's left: by the calendar (fixed installments —
/// nothing to register) or a balance the user informs from time to time.
enum DebtKind { parcelaFixa, saldoVariavel }

class Debt {
  const Debt({
    required this.id,
    required this.creditor,
    required this.type,
    required this.status,
    required this.kind,
    required this.currentBalance,
    this.installmentAmount,
    this.installmentDueDay,
    this.installmentsTotal,
    this.payoffAmount,
    this.monthlyInterestRate,
    this.notes,
  });

  final String id;
  final String creditor;
  final DebtType type;
  final DebtStatus status;
  final DebtKind kind;
  final String currentBalance;
  final String? installmentAmount;
  final int? installmentDueDay;
  final int? installmentsTotal;
  final String? payoffAmount;
  final String? monthlyInterestRate;
  final String? notes;

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: json['id'] as String,
      creditor: json['creditor'] as String,
      type: DebtTypeX.fromApi(json['type'] as String),
      status: DebtStatusX.fromApi(json['status'] as String),
      kind: json['kind'] == 'parcela_fixa'
          ? DebtKind.parcelaFixa
          : DebtKind.saldoVariavel,
      currentBalance: json['currentBalance'] as String,
      installmentAmount: json['installmentAmount'] as String?,
      installmentDueDay: json['installmentDueDay'] as int?,
      installmentsTotal: json['installmentsTotal'] as int?,
      payoffAmount: json['payoffAmount'] as String?,
      monthlyInterestRate: json['monthlyInterestRate'] as String?,
      notes: json['notes'] as String?,
    );
  }
}
