import 'what_if.dart';

/// "Compra de bem" (imóvel, carro): what to simulate. Amounts API-style
/// ("320000.00").
class AssetPurchaseRequest {
  const AssetPurchaseRequest({
    required this.assetKind,
    required this.price,
    required this.downPaymentAccountId,
    this.description,
    this.producesIncome = false,
    this.taxes,
    this.fees,
    this.downPayment,
    this.financing,
  });

  final String? description;

  /// imovel | veiculo | outro
  final String assetKind;
  final bool producesIncome;
  final String price;
  final String? taxes;
  final String? fees;
  final String? downPayment;
  final String downPaymentAccountId;
  final AssetFinancing? financing;

  Map<String, dynamic> toJson() => {
    if (description != null && description!.trim().isNotEmpty)
      'description': description!.trim(),
    'assetKind': assetKind,
    'producesIncome': producesIncome,
    'price': price,
    'taxes': ?taxes,
    'fees': ?fees,
    'downPayment': ?downPayment,
    'downPaymentAccountId': downPaymentAccountId,
    if (financing != null) 'financing': financing!.toJson(),
  };
}

class AssetFinancing {
  const AssetFinancing({
    required this.installments,
    required this.installmentAmount,
    this.principal,
    this.installmentAccountId,
  });

  final int installments;
  final String installmentAmount;

  /// Saldo devedor right after buying (what the contract says is financed).
  final String? principal;
  final String? installmentAccountId;

  Map<String, dynamic> toJson() => {
    'installments': installments,
    'installmentAmount': installmentAmount,
    'principal': ?principal,
    'installmentAccountId': ?installmentAccountId,
  };
}

/// One side (antes/depois) of the patrimônio.
class AssetPurchaseSide {
  const AssetPurchaseSide(this.json);

  final Map<String, dynamic> json;

  String get total => json['total'] as String;
  String get saldoDevedor => json['saldoDevedor'] as String;
  String get liquido => json['liquido'] as String;
  String? get percentLiquido => json['percentLiquido'] as String?;
  bool get alerta => json['alertaAbaixoDe40'] as bool? ?? false;
  String? get reservaMeses => json['reservaMeses'] as String?;
  String? blocoPercent(String bloco) =>
      (json['blocos'] as Map?)?[bloco]?['percent'] as String?;
}

class AssetPurchaseResult {
  const AssetPurchaseResult({
    required this.verdict,
    required this.headline,
    required this.lines,
    required this.before,
    required this.after,
    required this.totalCost,
    required this.reserveTargetMonths,
  });

  final WhatIfVerdict verdict;
  final String headline;
  final List<String> lines;
  final AssetPurchaseSide before;
  final AssetPurchaseSide after;
  final String totalCost;
  final int reserveTargetMonths;

  factory AssetPurchaseResult.fromJson(Map<String, dynamic> json) =>
      AssetPurchaseResult(
        verdict: WhatIfVerdict.parse(json['veredito'] as String),
        headline: json['manchete'] as String,
        lines: [for (final l in json['linhas'] as List) l as String],
        before: AssetPurchaseSide(Map<String, dynamic>.from(json['antes'])),
        after: AssetPurchaseSide(Map<String, dynamic>.from(json['depois'])),
        totalCost: (json['custo'] as Map)['total'] as String,
        reserveTargetMonths: (json['reserva'] as Map)['metaMeses'] as int,
      );
}
