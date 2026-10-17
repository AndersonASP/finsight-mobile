import 'package:dio/dio.dart';
import 'package:finsight/core/network/network_providers.dart';
import 'package:finsight/features/scenarios/presentation/scenario_day_detail_screen.dart';
import 'package:finsight/features/scenarios/presentation/scenario_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _scenarioId = 'scn-1';

class _FakeBackend {
  Map<String, dynamic>? lastTransactionPosted;
  String? lastDeletedTransactionId;

  Dio buildDio() {
    final now = DateTime.now();
    final day1 = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';

    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/scenarios/$_scenarioId' &&
              options.method == 'GET') {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'id': _scenarioId,
                  'name': 'E se eu gastar mais?',
                  'status': 'draft',
                  'description': null,
                },
                statusCode: 200,
              ),
            );
          }
          if (options.path == '/scenarios/$_scenarioId/daily-balance') {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: [
                  {
                    'day': 1,
                    'date': day1,
                    'entrada': '0.00',
                    'saida': '63.70',
                    'saidaShadow': true,
                    'diario': '0.00',
                    'diarioIsForecast': false,
                    'economia': '0.00',
                    'cartao': '0.00',
                    'saldo': '950.00',
                  },
                ],
                statusCode: 200,
              ),
            );
          }
          if (options.path == '/scenarios/$_scenarioId/day-detail') {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'real': [],
                  'shadow': [
                    {
                      'id': 'tx-1',
                      'kind': 'transaction',
                      'type': 'saida',
                      'description': 'Gasto simulado',
                      'date': day1,
                      'amount': '63.70',
                      'categoryName': null,
                      'categoryColor': null,
                    },
                  ],
                },
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
                    'name': 'Conta',
                    'type': 'checking',
                    'initialBalance': '0.00',
                  },
                ],
                statusCode: 200,
              ),
            );
          }
          if (options.path == '/scenarios/$_scenarioId/transactions' &&
              options.method == 'POST') {
            lastTransactionPosted = options.data as Map<String, dynamic>;
            return handler.resolve(
              Response(
                requestOptions: options,
                data: {'id': 'tx-new'},
                statusCode: 201,
              ),
            );
          }
          if (options.path.startsWith(
                '/scenarios/$_scenarioId/transactions/',
              ) &&
              options.method == 'DELETE') {
            lastDeletedTransactionId = options.path.split('/').last;
            return handler.resolve(
              Response(requestOptions: options, data: null, statusCode: 204),
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
    return dio;
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  Future<void> pump(WidgetTester tester, Dio dio) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: const MaterialApp(
          home: ScenarioDetailScreen(scenarioId: _scenarioId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows the scenario name/status and renders the shadow cell in italic',
    (WidgetTester tester) async {
      await pump(tester, _FakeBackend().buildDio());

      expect(find.text('E se eu gastar mais?'), findsOneWidget);
      expect(find.text('Rascunho'), findsOneWidget);

      final amountText = tester.widget<Text>(
        find.textContaining('63,70').first,
      );
      expect(amountText.style?.fontStyle, FontStyle.italic);
    },
  );

  testWidgets(
    'long-pressing a cell opens the add sheet preset to that type, and saving posts it',
    (WidgetTester tester) async {
      final backend = _FakeBackend();
      await pump(tester, backend.buildDio());

      await tester.longPress(find.textContaining('63,70').first);
      await tester.pumpAndSettle();

      expect(find.text('Novo item simulado'), findsOneWidget);
      expect(find.text('Saída'), findsOneWidget); // preset from the long-press

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conta').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '7500');

      await tester.tap(
        find.widgetWithText(FilledButton, 'Adicionar ao cenário'),
      );
      await tester.pumpAndSettle();

      expect(backend.lastTransactionPosted, isNotNull);
      expect(backend.lastTransactionPosted!['type'], 'saida');
      expect(backend.lastTransactionPosted!['amount'], '75.00');
      expect(backend.lastTransactionPosted!['accountId'], 'acc-1');
    },
  );

  testWidgets(
    'tapping the saldo cell opens the day detail, and removing a shadow item deletes it',
    (WidgetTester tester) async {
      final backend = _FakeBackend();
      await pump(tester, backend.buildDio());

      await tester.tap(find.byKey(const ValueKey('saldo-column-1')));
      await tester.pumpAndSettle();

      expect(find.byType(ScenarioDayDetailScreen), findsOneWidget);
      expect(find.text('Simulado'), findsOneWidget);
      expect(find.text('Nenhuma movimentação neste dia.'), findsNothing);

      await tester.longPress(find.textContaining('63,70').first);
      await tester.pumpAndSettle();

      expect(find.text('Remover da simulação?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
      await tester.pumpAndSettle();

      expect(backend.lastDeletedTransactionId, 'tx-1');
    },
  );
}
