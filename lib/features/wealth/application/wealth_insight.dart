import 'package:intl/intl.dart';
import '../../../core/format/money.dart';
import '../data/wealth.dart';

enum InsightTone { bom, atencao, ruim, neutro }

/// The Patrimônio headline: are you getting richer or poorer, and the few
/// things to do about it. Pure text over the API's numbers — no math beyond
/// comparisons, so nothing here can disagree with what the API computed.
class WealthInsight {
  const WealthInsight({
    required this.tone,
    required this.title,
    required this.tips,
    this.change,
    this.changeLabel,
  });

  final InsightTone tone;
  final String title;

  /// e.g. "+R$ 820,00" — null when there's nothing to compare yet.
  final String? change;

  /// e.g. "por mês, na média dos últimos meses" / "desde setembro".
  final String? changeLabel;

  /// Most important first, at most 3.
  final List<String> tips;
}

double _n(String? value) => double.tryParse(value ?? '') ?? 0;

String _money(double value) => formatCurrency(value.abs().toStringAsFixed(2));

WealthInsight buildWealthInsight(WealthSummary summary) {
  final d = summary.diagnosis;
  final variacao = _n(d.variacao);
  final juros = _n(d.jurosMensais);
  final dividaCara = _n(d.dividaCara);
  final financeiro = _n(summary.financialNetWorth);
  final hasExpensiveDebt = dividaCara > 0;

  final (title, trendTone) = switch (d.tendencia) {
    WealthTrend.crescendo => ('Você está ficando mais rico', InsightTone.bom),
    WealthTrend.caindo => ('Você está ficando mais pobre', InsightTone.ruim),
    WealthTrend.estavel => ('Seu patrimônio está parado', InsightTone.atencao),
    null => ('Ainda sem dados para comparar', InsightTone.neutro),
  };
  // Growing while paying expensive interest still deserves a warning.
  final tone =
      (hasExpensiveDebt || d.disponivelNegativo) &&
          trendTone != InsightTone.ruim
      ? InsightTone.atencao
      : trendTone;

  final tips = <String>[
    if (hasExpensiveDebt)
      juros > 0
          ? 'Você paga ${_money(juros)} por mês só de juros. Quitar as dívidas '
                'caras (${_money(dividaCara)}) vem antes de guardar ou investir.'
          : 'Você tem ${_money(dividaCara)} em dívidas caras (rotativo, cheque '
                'especial). Quitar elas vem antes de guardar ou investir.',
    if (d.disponivelNegativo)
      'Sua conta está no negativo. Se for cheque especial, os juros estão '
          'entre os mais altos que existem: sair dele é a prioridade.',
    if (financeiro < 0)
      'Em dinheiro, você deve ${_money(financeiro)} a mais do que tem. Bens '
          '(carro, imóvel) não entram nessa conta: eles não pagam boletos.',
    if (d.tendencia == WealthTrend.caindo && !hasExpensiveDebt)
      'Você está gastando mais do que ganha. Veja em Totais onde dá para cortar.',
    if (_n(d.reserva) <= 0 && !hasExpensiveDebt)
      'Você ainda não tem reserva de emergência. Guarde um pouco todo mês até '
          'cobrir 6 meses do seu custo de vida.',
    if (d.tendencia == WealthTrend.crescendo &&
        !hasExpensiveDebt &&
        !d.disponivelNegativo &&
        financeiro >= 0)
      'Continue assim. Com a reserva completa, o próximo passo é investir o '
          'que sobra.',
    if (d.tendencia == null)
      'Depois de um mês completo de lançamentos, aparece aqui se você está '
          'ficando mais rico ou mais pobre.',
  ];

  return WealthInsight(
    tone: tone,
    title: title,
    change: d.variacao == null
        ? null
        : '${variacao >= 0 ? '+' : '−'}${_money(variacao)}',
    changeLabel: d.variacao == null
        ? null
        : d.isMonthlyAverage
        ? 'por mês, na média dos últimos meses'
        : d.since != null
        ? 'desde ${DateFormat.MMMM('pt_BR').format(d.since!)}'
        : null,
    tips: tips.take(3).toList(),
  );
}
