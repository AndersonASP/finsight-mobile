import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/providers/selected_month_provider.dart';

class Overspending {
  const Overspending({
    required this.categoryName,
    required this.current,
    required this.average,
    required this.excess,
  });

  final String categoryName;
  final String current;
  final String average;
  final String excess;

  factory Overspending.fromJson(Map<String, dynamic> json) => Overspending(
    categoryName: json['categoryName'] as String,
    current: json['current'] as String,
    average: json['average'] as String,
    excess: json['excess'] as String,
  );
}

/// Where the money saved this month should go first.
class SavingsDestination {
  const SavingsDestination({
    required this.kind,
    required this.title,
    required this.detail,
  });

  /// `divida`, `reserva` or `investir`.
  final String kind;
  final String title;
  final String detail;

  factory SavingsDestination.fromJson(Map<String, dynamic> json) =>
      SavingsDestination(
        kind: json['kind'] as String,
        title: json['title'] as String,
        detail: json['detail'] as String,
      );
}

/// "Quanto dá para guardar este mês" — see the API's savings-capacity
/// service for the rules; every input comes back so the app can explain it.
class SavingsCapacity {
  const SavingsCapacity({
    required this.isPast,
    required this.entradas,
    required this.saidas,
    required this.cartao,
    required this.diarioReal,
    required this.diarioPrevisto,
    required this.economiaFeita,
    required this.sobraProjetada,
    required this.menorSaldoProjetado,
    required this.folga,
    required this.podeGuardarAgora,
    required this.limitadoPor,
    required this.totalPossivel,
    required this.percentPossivel,
    required this.metaPercent,
    required this.metaValor,
    required this.faltaParaMeta,
    required this.overspending,
    required this.destino,
  });

  final bool isPast;
  final String entradas;
  final String saidas;
  final String cartao;
  final String diarioReal;
  final String diarioPrevisto;
  final String economiaFeita;
  final String sobraProjetada;
  final String? menorSaldoProjetado;
  final String folga;
  final String podeGuardarAgora;

  /// `sobra`, `saldo` or `mes_encerrado`.
  final String limitadoPor;
  final String totalPossivel;
  final String percentPossivel;
  final String metaPercent;
  final String metaValor;
  final String faltaParaMeta;
  final List<Overspending> overspending;
  final SavingsDestination destino;

  factory SavingsCapacity.fromJson(Map<String, dynamic> json) =>
      SavingsCapacity(
        isPast: json['isPast'] as bool,
        entradas: json['entradas'] as String,
        saidas: json['saidas'] as String,
        cartao: json['cartao'] as String,
        diarioReal: json['diarioReal'] as String,
        diarioPrevisto: json['diarioPrevisto'] as String,
        economiaFeita: json['economiaFeita'] as String,
        sobraProjetada: json['sobraProjetada'] as String,
        menorSaldoProjetado: json['menorSaldoProjetado'] as String?,
        folga: json['folga'] as String,
        podeGuardarAgora: json['podeGuardarAgora'] as String,
        limitadoPor: json['limitadoPor'] as String,
        totalPossivel: json['totalPossivel'] as String,
        percentPossivel: json['percentPossivel'] as String,
        metaPercent: json['metaPercent'] as String,
        metaValor: json['metaValor'] as String,
        faltaParaMeta: json['faltaParaMeta'] as String,
        overspending: (json['overspending'] as List)
            .map((o) => Overspending.fromJson(Map<String, dynamic>.from(o)))
            .toList(),
        destino: SavingsDestination.fromJson(
          Map<String, dynamic>.from(json['destino'] as Map),
        ),
      );
}

Future<SavingsCapacity> _fetch(Dio dio, DateTime month) async {
  final response = await dio.get(
    '/insights/savings-capacity',
    queryParameters: {'year': month.year, 'month': month.month},
  );
  return SavingsCapacity.fromJson(Map<String, dynamic>.from(response.data));
}

/// For the month selected on the Totais tab.
final savingsCapacityProvider = FutureProvider.autoDispose<SavingsCapacity>((
  ref,
) {
  final month = ref.watch(selectedMonthProvider);
  return _fetch(ref.watch(dioProvider), month);
});
