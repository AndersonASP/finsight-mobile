import 'transaction_type.dart';

class FinTransaction {
  const FinTransaction({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.date,
    this.categoryId,
    this.description,
    this.counterpartAccountId,
  });

  final String id;
  final String accountId;
  final FinTransactionType type;
  final String amount;
  final DateTime date;
  final String? categoryId;
  final String? description;
  final String? counterpartAccountId;

  factory FinTransaction.fromJson(Map<String, dynamic> json) {
    return FinTransaction(
      id: json['id'] as String,
      accountId: json['accountId'] as String,
      type: FinTransactionTypeX.fromApi(json['type'] as String),
      amount: json['amount'] as String,
      date: DateTime.parse(json['date'] as String),
      categoryId: json['categoryId'] as String?,
      description: json['description'] as String?,
      counterpartAccountId: json['counterpartAccountId'] as String?,
    );
  }
}
