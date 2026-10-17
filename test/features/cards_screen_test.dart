import 'package:dio/dio.dart';
import 'package:finsight/core/network/network_providers.dart';
import 'package:finsight/features/cards/presentation/cards_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Dio _buildFakeDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final Object data = switch (options.path) {
          '/cards' => [
            {
              'id': 'card-1',
              'name': 'Nubank',
              'brand': null,
              'closingDay': 10,
              'dueDay': 17,
              'defaultPaymentAccountId': 'acc-1',
            },
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

  testWidgets('Cards screen lists cards with closing/due days', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(_buildFakeDio())],
        child: const MaterialApp(home: CardsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nubank'), findsOneWidget);
    expect(find.text('fecha dia 10 · vence dia 17'), findsOneWidget);
  });

  testWidgets(
    'creating a card posts name, closing/due days and payment account',
    (WidgetTester tester) async {
      Map<String, dynamic>? lastCardPosted;
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
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
            if (options.path == '/cards' && options.method == 'POST') {
              lastCardPosted = options.data as Map<String, dynamic>;
              return handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'id': 'card-new',
                    'name': lastCardPosted!['name'],
                    'brand': null,
                    'closingDay': lastCardPosted!['closingDay'],
                    'dueDay': lastCardPosted!['dueDay'],
                    'defaultPaymentAccountId':
                        lastCardPosted!['defaultPaymentAccountId'],
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
          child: const MaterialApp(home: CardsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Nome (ex: Nubank)'),
        'Itaú',
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conta corrente').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(lastCardPosted, isNotNull);
      expect(lastCardPosted!['name'], 'Itaú');
      expect(lastCardPosted!['closingDay'], 1);
      expect(lastCardPosted!['dueDay'], 10);
      expect(lastCardPosted!['defaultPaymentAccountId'], 'acc-1');
    },
  );
}
