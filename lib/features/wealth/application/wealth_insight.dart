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
  final reserveMonths = summary.reserveMonths == null
      ? null
      : _n(summary.reserveMonths);
  final target = summary.reserveTargetMonths;

  final (title, trendTone) = switch (d.tendencia) {
    WealthTrend.crescendo => ('Você está ficando mais rico', InsightTone.bom),
    WealthTrend.caindo => ('Você está ficando mais pobre', InsightTone.ruim),
    WealthTrend.estavel => ('Seu patrimônio está parado', InsightTone.atencao),
    null => ('Ainda sem dados para comparar', InsightTone.neutro),
  };
  // Growing while under 40% líquido or paying expensive interest still
  // deserves a warning.
  final tone =
      (hasExpensiveDebt || d.disponivelNegativo || summary.netWorthAlert) &&
          trendTone != InsightTone.ruim
      ? InsightTone.atencao
      : trendTone;

  // Método's order: reserve up to the target first, then expensive debt,
  // then investing.
  final tips = <String>[
    if (d.disponivelNegativo)
      'Sua conta está no negativo. Se for cheque especial, os juros estão '
          'entre os mais altos que existem: sair dele é urgente.',
    if (!summary.reserveComplete)
      _n(d.reserva) <= 0
          ? 'Você ainda não tem reserva de emergência. Ela vem antes de tudo: '
                'guarde todo mês até cobrir $target meses do seu custo de vida.'
          : reserveMonths == null
          ? 'Sua reserva vem antes de tudo até cobrir $target meses do seu '
                'custo de vida.'
          : 'Sua reserva cobre ${reserveMonths.toStringAsFixed(1).replaceAll('.', ',')} '
                'de $target meses${summary.reserveMissing != null ? ' (faltam ${formatCurrency(summary.reserveMissing!)})' : ''}. '
                'Completar ela vem antes de investir ou quitar dívidas.',
    if (summary.reserveComplete && hasExpensiveDebt)
      juros > 0
          ? 'Reserva completa. Agora as dívidas caras (${_money(dividaCara)}): '
                'você paga ${_money(juros)} por mês só de juros.'
          : 'Reserva completa. Agora quite as dívidas caras '
                '(${_money(dividaCara)}, rotativo ou cheque especial).',
    if (summary.netWorthAlert)
      'Só ${summary.netWorthPercent!.replaceAll('.', ',')}% do que você tem é seu '
          '(o farol é ${summary.netWorthMinPercent}%). Não faça novas dívidas'
          '${summary.reserveComplete ? ' e use a sobra para amortizar parcelas.' : ' e guarde mais.'}',
    if (financeiro < 0)
      'Livre em dinheiro, você deve ${_money(financeiro)} a mais do que tem. '
          'Bens (carro, imóvel) não entram nessa conta: eles não pagam boletos.',
    if (d.tendencia == WealthTrend.caindo)
      'Seu patrimônio caiu. Veja se você gastou mais do que ganhou (Totais) '
          'ou se algum bem perdeu valor.',
    if (d.tendencia == WealthTrend.crescendo &&
        summary.reserveComplete &&
        !hasExpensiveDebt &&
        !summary.netWorthAlert)
      'Continue assim. Com a reserva completa, o que sobra pode ir para '
          'investimentos ou para a entrada de um bem — prefira o que valoriza.',
    if (d.tendencia == null)
      'Depois de um mês completo de lançamentos, aparece aqui se você está '
          'ficando mais rico ou mais pobre.',
  ];

  final financialChange = d.variacaoFinanceira == null
      ? null
      : _n(d.variacaoFinanceira);
  final sinceLabel = d.isMonthlyAverage
      ? 'por mês, na média dos últimos meses'
      : d.since != null
      ? 'desde ${DateFormat.MMMM('pt_BR').format(d.since!)}'
      : null;
  return WealthInsight(
    tone: tone,
    title: title,
    change: d.variacao == null
        ? null
        : '${variacao >= 0 ? '+' : '−'}${_money(variacao)}',
    changeLabel: d.variacao == null
        ? null
        : [
            ?sinceLabel,
            if (financialChange != null)
              'em dinheiro livre: ${financialChange >= 0 ? '+' : '−'}${_money(financialChange)}',
          ].join(' · '),
    tips: tips.take(3).toList(),
  );
}
