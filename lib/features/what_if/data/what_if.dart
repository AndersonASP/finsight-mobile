/// "E se?" — see the API's what-if service. Every number and sentence comes
/// from the server (deterministic rules); the app only shows them.
library;

/// `cabe`, `aperta`, `fura_reserva` or `nao_cabe`.
enum WhatIfVerdict {
  cabe,
  aperta,
  furaReserva,
  naoCabe;

  static WhatIfVerdict parse(String value) => switch (value) {
    'cabe' => cabe,
    'aperta' => aperta,
    'fura_reserva' => furaReserva,
    _ => naoCabe,
  };

  String get label => switch (this) {
    cabe => 'Cabe',
    aperta => 'Aperta',
    furaReserva => 'Fura a reserva',
    naoCabe => 'Não cabe',
  };
}

/// How the purchase would be paid; [decide] lets the app pick.
sealed class WhatIfPayment {
  const WhatIfPayment();

  Map<String, dynamic> toJson();
}

class PayDecide extends WhatIfPayment {
  const PayDecide();

  @override
  Map<String, dynamic> toJson() => {'method': 'decide'};
}

class PayPix extends WhatIfPayment {
  const PayPix();

  @override
  Map<String, dynamic> toJson() => {'method': 'pix'};
}

class PayCard extends WhatIfPayment {
  const PayCard({required this.cardId, required this.installments});

  final String cardId;
  final int installments;

  @override
  Map<String, dynamic> toJson() => {
    'method': 'card',
    'cardId': cardId,
    'installments': installments,
  };
}

class WhatIfRequest {
  const WhatIfRequest({
    required this.amount,
    this.description,
    this.payment = const PayDecide(),
    this.pixDiscountPercent,
    this.interestFreeInstallments,
    this.recurring = false,
  });

  /// API-style decimal ("3000.00").
  final String amount;
  final String? description;
  final WhatIfPayment payment;
  final double? pixDiscountPercent;
  final int? interestFreeInstallments;
  final bool recurring;

  Map<String, dynamic> toJson() => {
    'amount': amount,
    if (description != null && description!.trim().isNotEmpty)
      'description': description!.trim(),
    'payment': payment.toJson(),
    'pixDiscountPercent': ?pixDiscountPercent,
    'interestFreeInstallments': ?interestFreeInstallments,
    if (recurring) 'recurring': true,
  };
}

class WhatIfMonth {
  const WhatIfMonth({
    required this.mes,
    required this.pagaNoMes,
    required this.menorSaldoAntes,
    required this.menorSaldoDepois,
    required this.guardaAntes,
    required this.guardaDepois,
    required this.meta,
    required this.ficaAbaixoDaMeta,
    required this.ficaNegativo,
  });

  /// YYYY-MM
  final String mes;
  final String pagaNoMes;
  final String? menorSaldoAntes;
  final String? menorSaldoDepois;
  final String guardaAntes;
  final String guardaDepois;
  final String meta;
  final bool ficaAbaixoDaMeta;
  final bool ficaNegativo;

  DateTime get month {
    final parts = mes.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1]);
  }

  factory WhatIfMonth.fromJson(Map<String, dynamic> json) => WhatIfMonth(
    mes: json['mes'] as String,
    pagaNoMes: json['pagaNoMes'] as String,
    menorSaldoAntes: (json['menorSaldoAntes'] as Map?)?['valor'] as String?,
    menorSaldoDepois: (json['menorSaldoDepois'] as Map?)?['valor'] as String?,
    guardaAntes: json['guardaAntes'] as String,
    guardaDepois: json['guardaDepois'] as String,
    meta: json['meta'] as String,
    ficaAbaixoDaMeta: json['ficaAbaixoDaMeta'] as bool,
    ficaNegativo: json['ficaNegativo'] as bool,
  );
}

class WhatIfOption {
  const WhatIfOption({
    required this.isCard,
    required this.cardId,
    required this.nome,
    required this.parcelas,
    required this.valorTotal,
    required this.valorParcela,
    required this.verdict,
    required this.meses,
    this.menorSaldo,
    this.menorSaldoData,
    this.menorSaldoSemACompra,
  });

  final bool isCard;
  final String? cardId;
  final String nome;
  final int parcelas;
  final String valorTotal;
  final String valorParcela;
  final WhatIfVerdict verdict;
  final List<WhatIfMonth> meses;

  /// Lowest projected saldo with this option, and when (YYYY-MM-DD).
  final String? menorSaldo;
  final String? menorSaldoData;

  /// The saldo on that same day without the purchase.
  final String? menorSaldoSemACompra;

  /// "Pix/débito", "Nubank em 1x", "Nubank em 3x".
  String get label => isCard ? '$nome em ${parcelas}x' : nome;

  factory WhatIfOption.fromJson(Map<String, dynamic> json) => WhatIfOption(
    isCard: json['forma'] == 'cartao',
    cardId: json['cardId'] as String?,
    nome: json['nome'] as String,
    parcelas: json['parcelas'] as int,
    valorTotal: json['valorTotal'] as String,
    valorParcela: json['valorParcela'] as String,
    verdict: WhatIfVerdict.parse(json['veredito'] as String),
    meses: (json['meses'] as List)
        .map((m) => WhatIfMonth.fromJson(Map<String, dynamic>.from(m)))
        .toList(),
    menorSaldo: (json['menorSaldo'] as Map?)?['valor'] as String?,
    menorSaldoData: (json['menorSaldo'] as Map?)?['data'] as String?,
    menorSaldoSemACompra:
        (json['menorSaldo'] as Map?)?['semACompra'] as String?,
  );
}

/// "O que você precisa": what it takes to buy without going negative and
/// while saving the target — sentences plus the headline monthly figure.
class WhatIfPlan {
  const WhatIfPlan({
    required this.linhas,
    required this.porMes,
    required this.meses,
  });

  final List<String> linhas;

  /// Total spending cut (or extra income) per month, as a decimal string.
  final String porMes;
  final int meses;

  factory WhatIfPlan.fromJson(Map<String, dynamic> json) => WhatIfPlan(
    linhas: List<String>.from(json['linhas'] as List),
    porMes: json['porMes'] as String,
    meses: json['meses'] as int,
  );
}

/// The emergency reserve today, against the 6-month target.
class WhatIfReserve {
  const WhatIfReserve({
    required this.saldo,
    required this.meses,
    required this.metaMeses,
    required this.completa,
  });

  final String saldo;

  /// Months of living cost covered ("2.5"), null when there's no cost yet.
  final String? meses;
  final int metaMeses;
  final bool completa;

  factory WhatIfReserve.fromJson(Map<String, dynamic> json) => WhatIfReserve(
    saldo: json['saldo'] as String,
    meses: json['meses'] as String?,
    metaMeses: json['metaMeses'] as int,
    completa: json['completa'] as bool,
  );
}

class WhatIfResult {
  const WhatIfResult({
    required this.descricao,
    required this.valor,
    required this.recorrente,
    required this.decidido,
    required this.verdict,
    required this.manchete,
    required this.motivos,
    required this.caminhos,
    required this.escolhida,
    required this.opcoes,
    required this.metaPercent,
    this.reserva,
    this.plano,
    this.diasDeDiario,
    this.percentDaEntrada,
  });

  final String? descricao;
  final String valor;
  final bool recorrente;
  final bool decidido;
  final WhatIfVerdict verdict;
  final String manchete;
  final List<String> motivos;
  final List<String> caminhos;
  final WhatIfOption escolhida;
  final List<WhatIfOption> opcoes;
  final String metaPercent;
  final WhatIfReserve? reserva;
  final WhatIfPlan? plano;

  /// The price in days of diário and in % of the month's entradas.
  final String? diasDeDiario;
  final String? percentDaEntrada;

  factory WhatIfResult.fromJson(Map<String, dynamic> json) => WhatIfResult(
    descricao: json['descricao'] as String?,
    valor: json['valor'] as String,
    recorrente: json['recorrente'] as bool,
    decidido: json['decidido'] as bool,
    verdict: WhatIfVerdict.parse(json['veredito'] as String),
    manchete: json['manchete'] as String,
    motivos: List<String>.from(json['motivos'] as List),
    caminhos: List<String>.from(json['caminhos'] as List),
    escolhida: WhatIfOption.fromJson(
      Map<String, dynamic>.from(json['escolhida'] as Map),
    ),
    opcoes: (json['opcoes'] as List)
        .map((o) => WhatIfOption.fromJson(Map<String, dynamic>.from(o)))
        .toList(),
    metaPercent: json['metaPercent'] as String,
    reserva: json['reserva'] is Map
        ? WhatIfReserve.fromJson(Map<String, dynamic>.from(json['reserva']))
        : null,
    plano: json['plano'] is Map
        ? WhatIfPlan.fromJson(Map<String, dynamic>.from(json['plano']))
        : null,
    diasDeDiario: (json['traducao'] as Map?)?['diasDeDiario'] as String?,
    percentDaEntrada:
        (json['traducao'] as Map?)?['percentDaEntrada'] as String?,
  );
}

/// An item of "Quero comprar", with today's simulation.
class WishlistItem {
  const WishlistItem({
    required this.id,
    required this.description,
    required this.amount,
    required this.pixDiscountPercent,
    required this.interestFreeInstallments,
    required this.simulacao,
  });

  final String id;
  final String description;
  final String amount;
  final String? pixDiscountPercent;
  final int interestFreeInstallments;
  final WhatIfResult simulacao;

  factory WishlistItem.fromJson(Map<String, dynamic> json) => WishlistItem(
    id: json['id'] as String,
    description: json['description'] as String,
    amount: json['amount'] as String,
    pixDiscountPercent: json['pixDiscountPercent'] as String?,
    interestFreeInstallments: json['interestFreeInstallments'] as int,
    simulacao: WhatIfResult.fromJson(
      Map<String, dynamic>.from(json['simulacao'] as Map),
    ),
  );
}
