import 'package:finsight/features/wealth/application/wealth_insight.dart';
import 'package:finsight/features/wealth/data/wealth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

WealthSummary _summary({
  required String financial,
  required WealthDiagnosis diagnosis,
}) => WealthSummary(
  netWorth: financial,
  financialNetWorth: financial,
  totalAssets: '0.00',
  totalLiabilities: '0.00',
  reserveLoansOwed: '0.00',
  staleCount: 0,
  assets: const [],
  liabilities: const [],
  diagnosis: diagnosis,
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  test('growing with no debt and a reserve: "mais rico" and keep going', () {
    final insight = buildWealthInsight(
      _summary(
        financial: '9000.00',
        diagnosis: const WealthDiagnosis(
          tendencia: WealthTrend.crescendo,
          variacao: '820.00',
          isMonthlyAverage: true,
          jurosMensais: '0.00',
          dividaCara: '0.00',
          reserva: '9000.00',
          disponivelNegativo: false,
        ),
      ),
    );
    expect(insight.tone, InsightTone.bom);
    expect(insight.title, 'Você está ficando mais rico');
    expect(insight.change, contains('820,00'));
    expect(insight.change, startsWith('+'));
    expect(insight.changeLabel, 'por mês, na média dos últimos meses');
    expect(insight.tips.single, startsWith('Continue assim'));
  });

  test('growing but paying expensive interest is a warning, debt first', () {
    final insight = buildWealthInsight(
      _summary(
        financial: '-3435.11',
        diagnosis: const WealthDiagnosis(
          tendencia: WealthTrend.crescendo,
          variacao: '500.00',
          isMonthlyAverage: true,
          jurosMensais: '300.00',
          dividaCara: '2500.00',
          reserva: '0.00',
          disponivelNegativo: true,
        ),
      ),
    );
    expect(insight.tone, InsightTone.atencao);
    expect(insight.tips, hasLength(3));
    expect(insight.tips[0], contains('300,00 por mês só de juros'));
    expect(insight.tips[1], contains('negativo'));
    expect(insight.tips[2], contains('3.435,11 a mais do que tem'));
  });

  test('no data yet says so instead of guessing', () {
    final insight = buildWealthInsight(
      _summary(financial: '0.00', diagnosis: WealthDiagnosis.empty),
    );
    expect(insight.tone, InsightTone.neutro);
    expect(insight.change, isNull);
    expect(insight.tips.last, contains('mês completo de lançamentos'));
  });
}
