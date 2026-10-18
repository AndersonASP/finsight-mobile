/// Where a number comes from — the basis for trusting it.
enum WealthSource { calculado, informado }

enum WealthItemKind { account, asset, debt, card }

class WealthItem {
  const WealthItem({
    required this.id,
    required this.kind,
    required this.name,
    required this.value,
    required this.source,
    required this.stale,
    this.asOf,
    this.note,
    this.details = const {},
  });

  final String id;
  final WealthItemKind kind;
  final String name;
  final String value;
  final WealthSource source;
  final DateTime? asOf;
  final bool stale;
  final String? note;
  final Map<String, dynamic> details;

  factory WealthItem.fromJson(Map<String, dynamic> json) {
    final asOf = json['asOf'] as String?;
    return WealthItem(
      id: json['id'] as String,
      kind: WealthItemKind.values.byName(json['kind'] as String),
      name: json['name'] as String,
      value: json['value'] as String,
      source: WealthSource.values.byName(json['source'] as String),
      asOf: asOf == null ? null : DateTime.parse(asOf),
      stale: json['stale'] as bool,
      note: json['note'] as String?,
      details: Map<String, dynamic>.from(json['details'] as Map? ?? const {}),
    );
  }
}

class WealthGroup {
  const WealthGroup({
    required this.group,
    required this.label,
    required this.total,
    required this.items,
  });

  final String group;
  final String label;
  final String total;
  final List<WealthItem> items;

  factory WealthGroup.fromJson(Map<String, dynamic> json) => WealthGroup(
    group: json['group'] as String,
    label: json['label'] as String,
    total: json['total'] as String,
    items: (json['items'] as List)
        .map((i) => WealthItem.fromJson(Map<String, dynamic>.from(i)))
        .toList(),
  );
}

enum WealthTrend { crescendo, caindo, estavel }

/// The API's deterministic "ficando mais rico ou mais pobre" figures — the
/// app only turns them into text (see wealth_insight.dart).
class WealthDiagnosis {
  const WealthDiagnosis({
    required this.jurosMensais,
    required this.dividaCara,
    required this.reserva,
    required this.disponivelNegativo,
    this.tendencia,
    this.variacao,
    this.isMonthlyAverage = false,
    this.since,
  });

  /// Null while there's no data to compare (no history, no full month).
  final WealthTrend? tendencia;

  /// Change of the financial net worth: since [since], or — when
  /// [isMonthlyAverage] — per month on average (no history yet).
  final String? variacao;
  final bool isMonthlyAverage;
  final DateTime? since;
  final String jurosMensais;
  final String dividaCara;
  final String reserva;
  final bool disponivelNegativo;

  static const empty = WealthDiagnosis(
    jurosMensais: '0.00',
    dividaCara: '0.00',
    reserva: '0.00',
    disponivelNegativo: false,
  );

  factory WealthDiagnosis.fromJson(Map<String, dynamic> json) {
    final desde = json['desde'] as Map?;
    return WealthDiagnosis(
      tendencia: switch (json['tendencia']) {
        'crescendo' => WealthTrend.crescendo,
        'caindo' => WealthTrend.caindo,
        'estavel' => WealthTrend.estavel,
        _ => null,
      },
      variacao: json['variacao'] as String?,
      isMonthlyAverage: json['base'] == 'media_mensal',
      since: desde == null
          ? null
          : DateTime(desde['year'] as int, desde['month'] as int),
      jurosMensais: json['jurosMensais'] as String,
      dividaCara: json['dividaCara'] as String,
      reserva: json['reserva'] as String,
      disponivelNegativo: json['disponivelNegativo'] as bool,
    );
  }
}

class WealthSummary {
  const WealthSummary({
    required this.netWorth,
    required this.financialNetWorth,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.reserveLoansOwed,
    required this.staleCount,
    required this.assets,
    required this.liabilities,
    this.previousNetWorth,
    this.reserveMonths,
    this.averageMonthlyCost,
    this.diagnosis = WealthDiagnosis.empty,
  });

  final String netWorth;
  final String financialNetWorth;
  final String totalAssets;
  final String totalLiabilities;
  final String? previousNetWorth;
  final String? reserveMonths;
  final String? averageMonthlyCost;
  final String reserveLoansOwed;
  final int staleCount;
  final List<WealthGroup> assets;
  final List<WealthGroup> liabilities;

  /// Empty when an older cached response (before the API had it) is shown.
  final WealthDiagnosis diagnosis;

  /// Informed values the user can update, stale ones first.
  List<WealthItem> get updatableItems {
    final items = [
      for (final g in [...assets, ...liabilities])
        for (final i in g.items)
          // Fixed-installment debts update themselves by the calendar.
          if (i.source == WealthSource.informado &&
              (i.kind != WealthItemKind.debt ||
                  i.details['debtKind'] == 'saldo_variavel'))
            i,
    ];
    items.sort((a, b) => (b.stale ? 1 : 0) - (a.stale ? 1 : 0));
    return items;
  }

  factory WealthSummary.fromJson(Map<String, dynamic> json) {
    List<WealthGroup> groups(String key) => (json[key] as List)
        .map((g) => WealthGroup.fromJson(Map<String, dynamic>.from(g)))
        .toList();
    return WealthSummary(
      netWorth: json['netWorth'] as String,
      financialNetWorth: json['financialNetWorth'] as String,
      totalAssets: json['totalAssets'] as String,
      totalLiabilities: json['totalLiabilities'] as String,
      previousNetWorth: json['previousNetWorth'] as String?,
      reserveMonths: json['reserveMonths'] as String?,
      averageMonthlyCost: json['averageMonthlyCost'] as String?,
      reserveLoansOwed: json['reserveLoansOwed'] as String,
      staleCount: json['staleCount'] as int,
      assets: groups('assets'),
      liabilities: groups('liabilities'),
      diagnosis: json['diagnostico'] is Map
          ? WealthDiagnosis.fromJson(
              Map<String, dynamic>.from(json['diagnostico'] as Map),
            )
          : WealthDiagnosis.empty,
    );
  }
}

class NetWorthPoint {
  const NetWorthPoint({required this.month, required this.netWorth});

  final DateTime month;
  final String netWorth;

  factory NetWorthPoint.fromJson(Map<String, dynamic> json) => NetWorthPoint(
    month: DateTime(json['year'] as int, json['month'] as int),
    netWorth: json['netWorth'] as String,
  );
}

enum AssetKind {
  imovel('Imóvel'),
  veiculo('Veículo'),
  aReceber('A receber'),
  outro('Outro bem');

  const AssetKind(this.label);

  final String label;

  String get apiValue => this == aReceber ? 'a_receber' : name;

  static AssetKind fromApi(String value) =>
      values.firstWhere((k) => k.apiValue == value);
}
