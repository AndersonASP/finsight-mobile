import 'package:dio/dio.dart';
import 'package:finsight/core/format/money.dart';
import 'package:finsight/core/network/network_providers.dart';
import 'package:finsight/features/ledger/presentation/day_detail_screen.dart';
import 'package:finsight/features/ledger/presentation/saldos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final _dayDetailItems = [
  {
    'id': 'tx-1',
    'type': 'saida',
    'description': 'Aluguel',
    'date': '2026-09-02',
    'amount': '150.00',
    'categoryId': 'cat-1',
    'categoryName': 'Casa',
    'categoryColor': '#D2531E',
    'installment': null,
  },
  {
    'id': 'inst-1',
    'type': 'cartao',
    'description': 'Parcela do carro',
    'date': '2026-09-02',
    'amount': '65.15',
    'categoryId': 'cat-2',
    'categoryName': 'Carro',
    'categoryColor': '#6A3FC7',
    'installment': {'sequence': 1, 'count': 17},
  },
];

Dio _buildFakeDio({
  List<Map<String, dynamic>> dayDetail = const [],
  List<Map<String, dynamic>> dailyBalance = const [],
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final Object data = switch (options.path) {
          '/reports/day-detail' => dayDetail,
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

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets(
    'Day detail screen shows title, date, tag, value and parcela count',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(
              _buildFakeDio(dayDetail: _dayDetailItems),
            ),
          ],
          child: MaterialApp(home: DayDetailScreen(date: DateTime(2026, 9, 2))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aluguel'), findsOneWidget);
      expect(find.text('Casa'), findsOneWidget);
      expect(find.text(formatCurrency('150.00')), findsOneWidget);

      expect(find.text('Parcela do carro'), findsOneWidget);
      expect(find.text('Carro'), findsOneWidget);
      expect(find.text(formatCurrency('65.15')), findsOneWidget);
      expect(find.text('# 1/17 mensais'), findsOneWidget);

      // Header shows "02/09" too, plus one per item — 3 total.
      expect(find.text('02/09'), findsNWidgets(3));
    },
  );

  testWidgets(
    'Day detail filter hides items that do not match the selected type',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(
              _buildFakeDio(dayDetail: _dayDetailItems),
            ),
          ],
          child: MaterialApp(home: DayDetailScreen(date: DateTime(2026, 9, 2))),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('todas'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'gastos com cartão'));
      await tester.pumpAndSettle();

      expect(find.text('Parcela do carro'), findsOneWidget);
      expect(find.text('Aluguel'), findsNothing);
    },
  );

  testWidgets(
    'Tapping a day\'s saldo on the Saldos screen opens its day detail',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dailyBalance = [
        {
          'day': 5,
          'date': '2026-10-05',
          'entrada': '0.00',
          'saida': '0.00',
          'diario': '0.00',
          'diarioIsForecast': false,
          'economia': '0.00',
          'cartao': '0.00',
          'saldo': '100.00',
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(
              _buildFakeDio(
                dailyBalance: dailyBalance,
                dayDetail: _dayDetailItems,
              ),
            ),
          ],
          child: const MaterialApp(home: SaldosScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('saldo-column-5')));
      await tester.pumpAndSettle();

      expect(find.byType(DayDetailScreen), findsOneWidget);
      expect(
        find.text('Aluguel'),
        findsOneWidget,
      ); // the fake day-detail response rendered
    },
  );

  testWidgets(
    'tapping a type cell (not saldo) opens day detail already filtered to that type',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dailyBalance = [
        {
          'day': 5,
          'date': '2026-10-05',
          'entrada': '0.00',
          'saida': '150.00', // matches the "Aluguel" item's amount below
          'diario': '0.00',
          'diarioIsForecast': false,
          'economia': '0.00',
          'cartao': '0.00',
          'saldo': '100.00',
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(
              _buildFakeDio(
                dailyBalance: dailyBalance,
                dayDetail: _dayDetailItems,
              ),
            ),
          ],
          child: const MaterialApp(home: SaldosScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(formatCurrency('150.00')));
      await tester.pumpAndSettle();

      expect(find.byType(DayDetailScreen), findsOneWidget);
      // Already filtered to "saída" — the cartão item never shows, no extra tap needed.
      expect(find.text('Aluguel'), findsOneWidget);
      expect(find.text('Parcela do carro'), findsNothing);
    },
  );
}
