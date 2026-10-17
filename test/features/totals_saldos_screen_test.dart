import 'package:dio/dio.dart';
import 'package:finsight/core/format/money.dart';
import 'package:finsight/core/network/network_providers.dart';
import 'package:finsight/core/theme/saldo_tier.dart';
import 'package:finsight/features/ledger/application/ledger_providers.dart';
import 'package:finsight/features/ledger/data/saldos_column_filter.dart';
import 'package:finsight/features/ledger/presentation/saldos_screen.dart';
import 'package:finsight/features/totals/presentation/totais_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// Canned responses mirroring a real backend run: a checking account seeded
/// with R$1000, a R$5000 entrada, a R$150 diário, and a R$500 economia
/// transfer to a reserve account (see the Phase 1 curl smoke test).
Dio _buildFakeDio({
  required Map<String, dynamic> monthlyTotals,
  required List<Map<String, dynamic>> dailyBalance,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final Object data = switch (options.path) {
          '/reports/monthly-totals' => monthlyTotals,
          '/reports/daily-balance' => dailyBalance,
          _ => <dynamic>[],
        };
        handler.resolve(
          Response(requestOptions: options, data: data, statusCode: 200),
        );
      },
    ),
  );
  return dio;
}

const _monthlyTotals = {
  'entradas': '5000.00',
  'saidas': '0.00',
  'diario': '150.00',
  'economia': '500.00',
  'cartao': '0.00',
  'performance': '4350.00',
  'custoDeVida': '650.00',
  'rendaExcedeCustoDeVida': true,
  'economizadoPercent': '10.00',
  'diarioMedioRealizado': '10.00',
  'diarioMedioPrevisto': '3.55',
};

final _dailyBalance = [
  {
    'day': 5,
    'date': '2026-10-05',
    'entrada': '5000.00',
    'saida': '0.00',
    'diario': '0.00',
    'diarioIsForecast': false,
    'economia': '0.00',
    'cartao': '0.00',
    'saldo': '6000.00',
  },
  {
    'day': 6,
    'date': '2026-10-06',
    'entrada': '0.00',
    'saida': '0.00',
    'diario': '150.00',
    'diarioIsForecast': false,
    'economia': '0.00',
    'cartao': '0.00',
    'saldo': '5850.00',
  },
  {
    'day': 7,
    'date': '2026-10-07',
    'entrada': '0.00',
    'saida': '0.00',
    'diario': '0.00',
    'diarioIsForecast': false,
    'economia': '500.00',
    'cartao': '0.00',
    'saldo': '5850.00', // transfer nets to zero in the running balance (RF-14)
  },
];

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('Totais screen renders monthly totals from the API', (
    WidgetTester tester,
  ) async {
    // Tall enough viewport that the whole "movimentações" list renders without
    // scrolling (ListView only mounts children within the viewport/cache extent).
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(
            _buildFakeDio(
              monthlyTotals: _monthlyTotals,
              dailyBalance: const [],
            ),
          ),
        ],
        child: const MaterialApp(home: TotaisScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(formatCurrency('4350.00')), findsOneWidget); // performance
    expect(find.text('sobrou dinheiro'), findsOneWidget);
    expect(find.text(formatPercent('10.00')), findsOneWidget); // economizado
    // Fixed 20%-30% savings target (no configurable goal menu anymore); 10% is below it.
    expect(find.text('abaixo da meta (20% a 30%)'), findsOneWidget);
    expect(
      find.text(formatCurrency('650.00')),
      findsOneWidget,
    ); // custo de vida
    expect(find.text('dentro da renda'), findsOneWidget);
    expect(find.text(formatCurrency('5000.00')), findsOneWidget); // entradas
    expect(find.text(formatCurrency('500.00')), findsOneWidget); // economia
  });

  testWidgets(
    'Saldos screen renders daily balance and nets transfers in saldo',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(
              _buildFakeDio(
                monthlyTotals: _monthlyTotals,
                dailyBalance: _dailyBalance,
              ),
            ),
          ],
          child: const MaterialApp(home: SaldosScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Day 7's transfer-to-reserve shows in the "economia" row...
      expect(find.text(formatCurrency('500.00')), findsOneWidget);
      // ...but the running saldo for day 7 stays the same as day 6 (R$5.850) —
      // the transfer doesn't reduce total patrimony, only "dinheiro livre".
      expect(find.text(formatCurrency('5850.00')), findsNWidgets(2));
      expect(find.text(formatCurrency('6000.00')), findsOneWidget);
    },
  );

  testWidgets(
    'a forecasted "diário" day renders in italic (previsão), a real one does not',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final days = [
        {
          'day': 1,
          'date': '2026-10-01',
          'entrada': '0.00',
          'saida': '0.00',
          'diario': '10.00',
          'diarioIsForecast': true,
          'economia': '0.00',
          'cartao': '0.00',
          'saldo': '990.00',
        },
        {
          'day': 2,
          'date': '2026-10-02',
          'entrada': '0.00',
          'saida': '0.00',
          'diario': '37.00',
          'diarioIsForecast': false,
          'economia': '0.00',
          'cartao': '0.00',
          'saldo': '953.00',
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(
              _buildFakeDio(monthlyTotals: _monthlyTotals, dailyBalance: days),
            ),
          ],
          child: const MaterialApp(home: SaldosScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final forecastValue = tester.widget<Text>(
        find.text(formatCurrency('10.00')),
      );
      expect(forecastValue.style?.fontStyle, FontStyle.italic);

      final realValue = tester.widget<Text>(find.text(formatCurrency('37.00')));
      expect(realValue.style?.fontStyle, isNot(FontStyle.italic));
    },
  );

  testWidgets(
    'a non-zero cell renders bold (but not too heavy); a zero cell stays regular',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final days = [
        {
          'day': 1,
          'date': '2026-10-01',
          'entrada': '0.00',
          'saida': '0.00',
          'diario': '0.00',
          'diarioIsForecast': false,
          'economia': '0.00',
          'cartao': '0.00',
          'saldo': '100.00',
        },
        {
          'day': 2,
          'date': '2026-10-02',
          'entrada': '0.00',
          'saida': '0.00',
          'diario': '75.00',
          'diarioIsForecast': false,
          'economia': '0.00',
          'cartao': '0.00',
          'saldo': '25.00',
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(
              _buildFakeDio(monthlyTotals: _monthlyTotals, dailyBalance: days),
            ),
            saldosColumnFilterProvider.overrideWith(
              (ref) => SaldosColumnFilter.diario,
            ),
          ],
          child: const MaterialApp(home: SaldosScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final zeroValue = tester.widget<Text>(find.text(formatCurrency('0.00')));
      expect(zeroValue.style?.fontWeight, isNot(FontWeight.w600));
      expect(zeroValue.style?.fontWeight, isNot(FontWeight.bold));

      final nonZeroValue = tester.widget<Text>(
        find.text(formatCurrency('75.00')),
      );
      expect(nonZeroValue.style?.fontWeight, FontWeight.w600);
    },
  );

  testWidgets(
    'a full 5-digit value fits the values column without being cut off by an ellipsis',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final days = [
        {
          'day': 1,
          'date': '2026-10-01',
          'entrada': '0.00',
          'saida': '0.00',
          'diario': '99999.99',
          'diarioIsForecast': false,
          'economia': '0.00',
          'cartao': '0.00',
          'saldo':
              '12345.67', // different from diario, so the finder below is unambiguous
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(
              _buildFakeDio(monthlyTotals: _monthlyTotals, dailyBalance: days),
            ),
            saldosColumnFilterProvider.overrideWith(
              (ref) => SaldosColumnFilter.diario,
            ),
          ],
          child: const MaterialApp(home: SaldosScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(formatCurrency('99999.99')).first,
      );
      expect(paragraph.didExceedMaxLines, isFalse);
    },
  );

  testWidgets(
    'Saldos column filter switches what the second column shows, and saldo tiers color correctly',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tieredDays = [
        {
          'day': 1,
          'date': '2026-10-01',
          'entrada': '3000.00',
          'saida': '0.00',
          'diario': '0.00',
          'diarioIsForecast': false,
          'economia': '0.00',
          'cartao': '0.00',
          'saldo':
              '2500.00', // >= 2000 -> strongGreen (kept distinct from entrada for the text lookup below)
        },
        {
          'day': 2,
          'date': '2026-10-02',
          'entrada': '0.00',
          'saida': '0.00',
          'diario': '0.00',
          'diarioIsForecast': false,
          'economia': '0.00',
          'cartao': '0.00',
          'saldo': '-600.00', // < -500 -> darkRed
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(
              _buildFakeDio(
                monthlyTotals: _monthlyTotals,
                dailyBalance: tieredDays,
              ),
            ),
          ],
          child: const MaterialApp(home: SaldosScreen()),
        ),
      );
      await tester.pumpAndSettle();

      Container saldoContainerFor(int day) =>
          tester.widget<Container>(find.byKey(ValueKey('saldo-column-$day')));

      expect(
        (saldoContainerFor(1).decoration as BoxDecoration?)?.color ??
            saldoContainerFor(1).color,
        SaldoTiers.backgroundFor(SaldoTier.strongGreen, Brightness.light),
      );
      expect(
        (saldoContainerFor(2).decoration as BoxDecoration?)?.color ??
            saldoContainerFor(2).color,
        SaldoTiers.backgroundFor(SaldoTier.darkRed, Brightness.light),
      );

      // Default filter is "todas" — day 1 shows all 5 type rows, including entrada.
      expect(find.text(formatCurrency('3000.00')), findsOneWidget);
      expect(find.text('todas'), findsOneWidget);
      // 5 stacked rows per day need 4 internal horizontal dividers between them;
      // across 2 days that's 8, plus the 1 fixed divider under the column header.
      expect(find.byType(Divider), findsNWidgets(9));

      // Switch the column to "entradas" via the header's bottom sheet.
      await tester.tap(find.text('todas'));
      await tester.pumpAndSettle();
      expect(find.text('entradas'), findsWidgets); // sheet option label
      await tester.tap(find.widgetWithText(ListTile, 'entradas'));
      await tester.pumpAndSettle();

      expect(
        find.text('entradas'),
        findsOneWidget,
      ); // now just the header label
      // With only "entradas" selected, day 2 (which has zero entrada) shows a single greyed row.
      expect(find.text(formatCurrency('0.00')), findsOneWidget);
      // A single row per day needs no internal dividers — only the header's remains.
      expect(find.byType(Divider), findsOneWidget);
    },
  );

  testWidgets(
    'long-pressing a typed cell opens the add form pre-filled with that day and type',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(
              _buildFakeDio(
                monthlyTotals: _monthlyTotals,
                dailyBalance: _dailyBalance,
              ),
            ),
          ],
          child: const MaterialApp(home: SaldosScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Day 6's "diário" row is the only R$150,00 cell in the fixture.
      await tester.longPress(find.text(formatCurrency('150.00')));
      await tester.pumpAndSettle();

      // Skips the type picker entirely — lands straight on the form, already
      // set to "diário" and dated for the day that was pressed.
      expect(find.text('Tipo de lançamento'), findsNothing);
      expect(find.text('diário'), findsOneWidget);
      expect(find.text('06/10/2026'), findsOneWidget);
    },
  );

  testWidgets(
    'saving a new lançamento refreshes the Saldos table without needing a manual reload',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var dailyBalanceCallCount = 0;
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/reports/daily-balance') {
              // Only the month on screen — neighbouring months are also
              // fetched in the background, for the offline cache.
              if (options.queryParameters['month'] == DateTime.now().month) {
                dailyBalanceCallCount++;
              }
              return handler.resolve(
                Response(
                  requestOptions: options,
                  data: _dailyBalance,
                  statusCode: 200,
                ),
              );
            }
            if (options.path == '/reports/monthly-totals') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  data: _monthlyTotals,
                  statusCode: 200,
                ),
              );
            }
            if (options.path == '/accounts' && options.method == 'GET') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  data: [
                    {
                      'id': 'acc-1',
                      'name': 'Conta corrente',
                      'type': 'checking',
                      'initialBalance': '0.00',
                    },
                  ],
                  statusCode: 200,
                ),
              );
            }
            if (options.path == '/transactions' && options.method == 'POST') {
              final body = options.data as Map<String, dynamic>;
              return handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'id': 'tx-new',
                    'accountId': body['accountId'],
                    'type': body['type'],
                    'amount': body['amount'],
                    'date': '${body['date']}T00:00:00.000Z',
                    'categoryId': null,
                    'description': null,
                    'counterpartAccountId': null,
                  },
                  statusCode: 201,
                ),
              );
            }
            handler.resolve(
              Response(
                requestOptions: options,
                data: <dynamic>[],
                statusCode: 200,
              ),
            );
          },
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [dioProvider.overrideWithValue(dio)],
          child: const MaterialApp(home: SaldosScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(dailyBalanceCallCount, 1);

      await tester.longPress(find.text(formatCurrency('150.00')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '5000'); // -> 50,00
      await tester.tap(find.widgetWithText(FilledButton, 'adicionar diário'));
      await tester.pumpAndSettle();

      expect(dailyBalanceCallCount, 2); // refetched automatically after saving
    },
  );

  testWidgets(
    '"ir para hoje" scrolls to today even when its row was never built (off-screen)',
    (WidgetTester tester) async {
      final now = DateTime.now();
      final totalDays = DateTime(now.year, now.month + 1, 0).day;
      final days = List.generate(totalDays, (i) {
        final day = i + 1;
        return {
          'day': day,
          'date':
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
          'entrada': '0.00',
          'saida': '0.00',
          'diario': '0.00',
          'diarioIsForecast': false,
          'economia': '0.00',
          'cartao': '0.00',
          'saldo': '0.00',
        };
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(
              _buildFakeDio(monthlyTotals: _monthlyTotals, dailyBalance: days),
            ),
          ],
          child: const MaterialApp(home: SaldosScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final todayKey = ValueKey('saldo-column-${now.day}');

      // Scroll hard towards whichever end of the month is farthest from today,
      // so today's row is guaranteed to be unmounted (ListView-style lists
      // only build what's near the viewport).
      final scrollTowardsEnd = now.day <= totalDays / 2;
      for (var i = 0; i < 20; i++) {
        await tester.drag(
          find.byType(ScrollablePositionedList),
          Offset(0, scrollTowardsEnd ? -2000 : 2000),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byKey(todayKey), findsNothing);

      await tester.tap(find.byTooltip('Ir para hoje'));
      await tester.pumpAndSettle();

      expect(find.byKey(todayKey), findsOneWidget);
    },
  );
}
