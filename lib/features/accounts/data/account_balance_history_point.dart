class AccountBalanceHistoryPoint {
  const AccountBalanceHistoryPoint({
    required this.year,
    required this.month,
    required this.balance,
  });

  final int year;
  final int month;
  final String balance;

  DateTime get asDate => DateTime(year, month);

  factory AccountBalanceHistoryPoint.fromJson(Map<String, dynamic> json) {
    return AccountBalanceHistoryPoint(
      year: json['year'] as int,
      month: json['month'] as int,
      balance: json['balance'] as String,
    );
  }
}
