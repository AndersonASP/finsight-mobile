import 'package:finsight/features/ledger/data/saldos_column_filter.dart';
import 'package:finsight/features/ledger/presentation/monthly_balance_table.dart';
import 'package:finsight/features/reports/data/daily_balance_day.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets(
    'swiping the middle column sideways steps through the column types',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var filter = SaldosColumnFilter.todas;
      final days = [
        DailyBalanceDay(
          day: 1,
          date: DateTime(2026, 9, 1),
          entrada: '10.00',
          saida: '0.00',
          diario: '0.00',
          diarioIsForecast: false,
          economia: '0.00',
          cartao: '0.00',
          saldo: '10.00',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => MonthlyBalanceTable(
                daysAsync: AsyncData(days),
                filter: filter,
                onFilterChanged: (value) => setState(() => filter = value),
                onCellTap: (_, _) {},
                onCellLongPress: (_, _) {},
                onSaldoTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final middle = find.byIcon(Icons.south_west_rounded).first;
      await tester.fling(middle, const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(filter, SaldosColumnFilter.entrada);

      await tester.fling(
        find.byIcon(Icons.south_west_rounded).first,
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(filter, SaldosColumnFilter.saida);

      await tester.fling(
        find.byIcon(Icons.north_east_rounded).first,
        const Offset(300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(filter, SaldosColumnFilter.entrada);

      // The first type is the left end: swiping right from it does nothing.
      await tester.fling(
        find.byIcon(Icons.south_west_rounded).first,
        const Offset(300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      await tester.fling(
        find.byIcon(Icons.south_west_rounded).first,
        const Offset(300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(filter, SaldosColumnFilter.todas);
    },
  );
}
