enum ReserveLoanStatus { active, settled }

extension ReserveLoanStatusX on ReserveLoanStatus {
  static ReserveLoanStatus fromApi(String value) => switch (value) {
    'active' => ReserveLoanStatus.active,
    'settled' => ReserveLoanStatus.settled,
    _ => throw ArgumentError('Unknown reserve loan status: $value'),
  };
}

class ReserveLoan {
  const ReserveLoan({
    required this.id,
    required this.reserveAccountId,
    required this.destinationAccountId,
    required this.principal,
    required this.borrowDate,
    required this.monthlyInterestRate,
    required this.status,
    this.description,
  });

  final String id;
  final String reserveAccountId;
  final String destinationAccountId;
  final String principal;
  final DateTime borrowDate;
  final String monthlyInterestRate;
  final ReserveLoanStatus status;
  final String? description;

  factory ReserveLoan.fromJson(Map<String, dynamic> json) {
    return ReserveLoan(
      id: json['id'] as String,
      reserveAccountId: json['reserveAccountId'] as String,
      destinationAccountId: json['destinationAccountId'] as String,
      principal: json['principal'] as String,
      borrowDate: DateTime.parse(json['borrowDate'] as String),
      monthlyInterestRate: json['monthlyInterestRate'] as String,
      status: ReserveLoanStatusX.fromApi(json['status'] as String),
      description: json['description'] as String?,
    );
  }
}

class ReserveLoanRepayment {
  const ReserveLoanRepayment({
    required this.id,
    required this.repaymentDate,
    required this.amount,
    required this.interestPortion,
    required this.principalPortion,
    required this.outstandingPrincipalAfter,
  });

  final String id;
  final DateTime repaymentDate;
  final String amount;
  final String interestPortion;
  final String principalPortion;
  final String outstandingPrincipalAfter;

  factory ReserveLoanRepayment.fromJson(Map<String, dynamic> json) {
    return ReserveLoanRepayment(
      id: json['id'] as String,
      repaymentDate: DateTime.parse(json['repaymentDate'] as String),
      amount: json['amount'] as String,
      interestPortion: json['interestPortion'] as String,
      principalPortion: json['principalPortion'] as String,
      outstandingPrincipalAfter: json['outstandingPrincipalAfter'] as String,
    );
  }
}

/// "Quanto devo agora" for a loan — principal still outstanding plus
/// interest accrued (but not yet paid) since the last settlement.
class ReserveLoanOwed {
  const ReserveLoanOwed({
    required this.outstandingPrincipal,
    required this.accruedInterest,
    required this.totalOwed,
  });

  final String outstandingPrincipal;
  final String accruedInterest;
  final String totalOwed;

  factory ReserveLoanOwed.fromJson(Map<String, dynamic> json) {
    return ReserveLoanOwed(
      outstandingPrincipal: json['outstandingPrincipal'] as String,
      accruedInterest: json['accruedInterest'] as String,
      totalOwed: json['totalOwed'] as String,
    );
  }
}
