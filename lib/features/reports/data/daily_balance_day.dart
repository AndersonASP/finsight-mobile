import '../../ledger/data/saldos_column_filter.dart';

class DailyBalanceDay {
  const DailyBalanceDay({
    required this.day,
    required this.date,
    required this.entrada,
    this.entradaShadow = false,
    required this.saida,
    this.saidaShadow = false,
    required this.diario,
    required this.diarioIsForecast,
    this.diarioShadow = false,
    required this.economia,
    this.economiaShadow = false,
    required this.cartao,
    this.cartaoShadow = false,
    required this.saldo,
  });

  final int day;
  final DateTime date;
  final String entrada;
  final String saida;
  final String diario;

  /// True when `diario` is "previsão de diário"'s projected daily average
  /// for this future day, not a real lançamento — see reports.service.ts's
  /// getDailyBalance.
  final bool diarioIsForecast;
  final String economia;
  final String cartao;
  final String saldo;

  /// True when this column, this day, includes at least one row from a
  /// scenario being simulated — only ever set when this came from
  /// `GET /scenarios/:id/daily-balance` instead of the real Saldos endpoint.
  final bool entradaShadow;
  final bool saidaShadow;
  final bool diarioShadow;
  final bool economiaShadow;
  final bool cartaoShadow;

  bool shadowFor(SaldosColumnFilter type) => switch (type) {
    SaldosColumnFilter.entrada => entradaShadow,
    SaldosColumnFilter.saida => saidaShadow,
    SaldosColumnFilter.diario => diarioShadow,
    SaldosColumnFilter.economia => economiaShadow,
    SaldosColumnFilter.cartao => cartaoShadow,
    SaldosColumnFilter.todas => false,
  };

  bool get hasActivity =>
      double.parse(entrada) != 0 ||
      double.parse(saida) != 0 ||
      double.parse(diario) != 0 ||
      double.parse(economia) != 0 ||
      double.parse(cartao) != 0;

  factory DailyBalanceDay.fromJson(Map<String, dynamic> json) {
    return DailyBalanceDay(
      day: json['day'] as int,
      date: DateTime.parse(json['date'] as String),
      entrada: json['entrada'] as String,
      entradaShadow: json['entradaShadow'] as bool? ?? false,
      saida: json['saida'] as String,
      saidaShadow: json['saidaShadow'] as bool? ?? false,
      diario: json['diario'] as String,
      diarioIsForecast: json['diarioIsForecast'] as bool,
      diarioShadow: json['diarioShadow'] as bool? ?? false,
      economia: json['economia'] as String,
      economiaShadow: json['economiaShadow'] as bool? ?? false,
      cartao: json['cartao'] as String,
      cartaoShadow: json['cartaoShadow'] as bool? ?? false,
      saldo: json['saldo'] as String,
    );
  }
}

class MonthlyTotals {
  const MonthlyTotals({
    required this.entradas,
    required this.saidas,
    required this.diario,
    required this.economia,
    required this.cartao,
    required this.performance,
    required this.custoDeVida,
    required this.rendaExcedeCustoDeVida,
    required this.economizadoPercent,
    required this.diarioMedioRealizado,
    required this.diarioMedioPrevisto,
  });

  final String entradas;
  final String saidas;
  final String diario;
  final String economia;
  final String cartao;
  final String performance;
  final String custoDeVida;
  final bool rendaExcedeCustoDeVida;
  final String economizadoPercent;
  final String diarioMedioRealizado;
  final String diarioMedioPrevisto;

  factory MonthlyTotals.fromJson(Map<String, dynamic> json) {
    return MonthlyTotals(
      entradas: json['entradas'] as String,
      saidas: json['saidas'] as String,
      diario: json['diario'] as String,
      economia: json['economia'] as String,
      cartao: json['cartao'] as String,
      performance: json['performance'] as String,
      custoDeVida: json['custoDeVida'] as String,
      rendaExcedeCustoDeVida: json['rendaExcedeCustoDeVida'] as bool,
      economizadoPercent: json['economizadoPercent'] as String,
      diarioMedioRealizado: json['diarioMedioRealizado'] as String,
      diarioMedioPrevisto: json['diarioMedioPrevisto'] as String,
    );
  }
}

class CardSpendingItem {
  const CardSpendingItem({
    required this.cardId,
    required this.name,
    required this.total,
  });

  final String cardId;
  final String name;
  final String total;

  factory CardSpendingItem.fromJson(Map<String, dynamic> json) {
    return CardSpendingItem(
      cardId: json['cardId'] as String,
      name: json['name'] as String,
      total: json['total'] as String,
    );
  }
}

class CategoryBreakdownItem {
  const CategoryBreakdownItem({
    required this.categoryId,
    required this.name,
    required this.color,
    required this.total,
  });

  final String categoryId;
  final String name;
  final String color;
  final String total;

  factory CategoryBreakdownItem.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdownItem(
      categoryId: json['categoryId'] as String,
      name: json['name'] as String,
      color: json['color'] as String,
      total: json['total'] as String,
    );
  }
}

class MonthlyTrendPoint {
  const MonthlyTrendPoint({
    required this.year,
    required this.month,
    required this.entradas,
    required this.saidas,
    required this.economia,
    required this.saldoFinal,
  });

  final int year;
  final int month;
  final String entradas;
  final String saidas;
  final String economia;
  final String saldoFinal;

  DateTime get asDate => DateTime(year, month);

  factory MonthlyTrendPoint.fromJson(Map<String, dynamic> json) {
    return MonthlyTrendPoint(
      year: json['year'] as int,
      month: json['month'] as int,
      entradas: json['entradas'] as String,
      saidas: json['saidas'] as String,
      economia: json['economia'] as String,
      saldoFinal: json['saldoFinal'] as String,
    );
  }
}

class BudgetVsActualItem {
  const BudgetVsActualItem({
    required this.categoryId,
    required this.name,
    required this.color,
    required this.budgeted,
    required this.actual,
  });

  final String categoryId;
  final String name;
  final String color;
  final String budgeted;
  final String actual;

  factory BudgetVsActualItem.fromJson(Map<String, dynamic> json) {
    return BudgetVsActualItem(
      categoryId: json['categoryId'] as String,
      name: json['name'] as String,
      color: json['color'] as String,
      budgeted: json['budgeted'] as String,
      actual: json['actual'] as String,
    );
  }
}
