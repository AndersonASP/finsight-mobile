class FinCard {
  const FinCard({
    required this.id,
    required this.name,
    this.brand,
    required this.closingDay,
    required this.dueDay,
    required this.defaultPaymentAccountId,
  });

  final String id;
  final String name;
  final String? brand;
  final int closingDay;
  final int dueDay;
  final String defaultPaymentAccountId;

  factory FinCard.fromJson(Map<String, dynamic> json) {
    return FinCard(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      closingDay: json['closingDay'] as int,
      dueDay: json['dueDay'] as int,
      defaultPaymentAccountId: json['defaultPaymentAccountId'] as String,
    );
  }
}
