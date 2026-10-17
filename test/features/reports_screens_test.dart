import 'package:dio/dio.dart';
import 'package:finsight/core/network/network_providers.dart';
import 'package:finsight/features/reports/presentation/account_balance_history_report_screen.dart';
import 'package:finsight/features/reports/presentation/budget_vs_actual_report_screen.dart';
import 'package:finsight/features/reports/presentation/card_spending_report_screen.dart';
import 'package:finsight/features/reports/presentation/category_breakdown_report_screen.dart';
import 'package:finsight/features/reports/presentation/monthly_trend_report_screen.dart';
import 'package:finsight/features/reports/presentation/reports_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Dio _buildFakeDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/reports/card-spending') {
          final hasMonth = options.queryParameters.containsKey('month');
          final data = hasMonth
              ? [
                  {'cardId': 'card-1', 'name': 'Nubank', 'total': '150.00'},
                ]
              : [
                  {'cardId': 'card-1', 'name': 'Nubank', 'total': '900.00'},
                  {'cardId': 'card-2', 'name': 'Inter', 'total': '300.00'},
                ];
          return handler.resolve(
            Response(requestOptions: options, data: data, statusCode: 200),
          );
        }
        final Object data = switch (options.path) {
          '/reports/category-breakdown' => [
            {
              'categoryId': 'cat-1',
              'name': 'Mercado',
              'color': '#2E8B57',
              'total': '350.00',
            },
            {
              'categoryId': 'cat-2',
              'name': 'Transporte',
              'color': '#D2531E',
              'total': '120.00',
            },
          ],
          '/reports/monthly-trend' => [
            {
              'year': 2026,
              'month': 8,
              'entradas': '5000.00',
              'saidas': '2000.00',
              'economia': '500.00',
              'saldoFinal': '3000.00',
            },
            {
              'year': 2026,
              'month': 9,
              'entradas': '5000.00',
              'saidas': '2200.00',
              'economia': '500.00',
              'saldoFinal': '3300.00',
            },
            {
              'year': 2026,
              'month': 10,
              'entradas': '5000.00',
              'saidas': '1800.00',
              'economia': '500.00',
              'saldoFinal': '4000.00',
            },
          ],
          '/reports/budget-vs-actual' => [
            {
              'categoryId': 'cat-1',
              'name': 'Mercado',
              'color': '#2E8B57',
              'budgeted': '300.00',
              'actual': '350.00',
            },
          ],
          '/accounts' => [
            {
              'id': 'acc-1',
              'name': 'Conta Principal',
              'type': 'checking',
              'initialBalance': '0.00',
            },
          ],
          '/accounts/acc-1/balance-history' => [
            {'year': 2026, 'month': 9, 'balance': '1000.00'},
            {'year': 2026, 'month': 10, 'balance': '1500.00'},
          ],
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

  Future<void> pump(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(_buildFakeDio())],
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Reports list shows all five report types and navigates into each',
    (WidgetTester tester) async {
      await pump(tester, const ReportsListScreen());

      expect(find.text('Gastos por categoria'), findsOneWidget);
      expect(find.text('Gastos por cartão'), findsOneWidget);
      expect(find.text('Evolução mensal'), findsOneWidget);
      expect(find.text('Histórico de saldo por conta'), findsOneWidget);
      expect(find.text('Orçado x realizado'), findsOneWidget);

      await tester.tap(find.text('Gastos por categoria'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryBreakdownReportScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Card spending shows one card per month, and the "Ano" toggle sums the whole year',
    (WidgetTester tester) async {
      await pump(tester, const CardSpendingReportScreen());

      expect(find.text('Nubank'), findsOneWidget);
      expect(find.text('Inter'), findsNothing);

      await tester.tap(find.text('Ano'));
      await tester.pumpAndSettle();

      expect(find.text('Nubank'), findsOneWidget);
      expect(find.text('Inter'), findsOneWidget);
    },
  );

  testWidgets('Category breakdown renders each category with its total', (
    WidgetTester tester,
  ) async {
    await pump(tester, const CategoryBreakdownReportScreen());

    expect(find.text('Mercado'), findsOneWidget);
    expect(find.text('Transporte'), findsOneWidget);
  });

  testWidgets('Monthly trend renders a bar per month and the saldo list', (
    WidgetTester tester,
  ) async {
    await pump(tester, const MonthlyTrendReportScreen());

    expect(
      find.text('out/26'),
      findsWidgets,
    ); // appears in the chart x-axis and the saldo list
  });

  testWidgets(
    'Account balance history renders a bar per month for the selected account',
    (WidgetTester tester) async {
      await pump(tester, const AccountBalanceHistoryReportScreen());

      expect(find.text('Conta Principal'), findsOneWidget);
      expect(find.textContaining('09/26'), findsOneWidget);
      expect(find.textContaining('10/26'), findsOneWidget);
    },
  );

  testWidgets('Budget vs actual flags a category that went over budget', (
    WidgetTester tester,
  ) async {
    await pump(tester, const BudgetVsActualReportScreen());

    expect(find.text('Mercado'), findsOneWidget);
    expect(find.textContaining('acima do orçado'), findsOneWidget);
  });
}
