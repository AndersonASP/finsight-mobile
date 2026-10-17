class BudgetItem {
  const BudgetItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.active,
  });

  final String id;
  final String name;
  final String amount;
  final bool active;

  factory BudgetItem.fromJson(Map<String, dynamic> json) {
    return BudgetItem(
      id: json['id'] as String,
      name: json['name'] as String,
      amount: json['amount'] as String,
      active: json['active'] as bool,
    );
  }
}

class BudgetSummary {
  const BudgetSummary({
    required this.total,
    required this.days,
    required this.dailyAverage,
  });

  final String total;
  final int days;
  final String dailyAverage;

  factory BudgetSummary.fromJson(Map<String, dynamic> json) {
    return BudgetSummary(
      total: json['total'] as String,
      days: json['days'] as int,
      dailyAverage: json['dailyAverage'] as String,
    );
  }
}
