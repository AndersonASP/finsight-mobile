enum AccountType { checking, cash, savingsReserve, investment }

extension AccountTypeX on AccountType {
  String get apiValue => switch (this) {
    AccountType.checking => 'checking',
    AccountType.cash => 'cash',
    AccountType.savingsReserve => 'savings_reserve',
    AccountType.investment => 'investment',
  };

  String get label => switch (this) {
    AccountType.checking => 'Conta corrente',
    AccountType.cash => 'Dinheiro',
    AccountType.savingsReserve => 'Reserva',
    AccountType.investment => 'Investimento',
  };

  static AccountType fromApi(String value) => switch (value) {
    'checking' => AccountType.checking,
    'cash' => AccountType.cash,
    'savings_reserve' => AccountType.savingsReserve,
    'investment' => AccountType.investment,
    _ => throw ArgumentError('Unknown account type: $value'),
  };
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.initialBalance,
  });

  final String id;
  final String name;
  final AccountType type;
  final String initialBalance;

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      name: json['name'] as String,
      type: AccountTypeX.fromApi(json['type'] as String),
      initialBalance: json['initialBalance'] as String,
    );
  }
}
