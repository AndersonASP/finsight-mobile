import 'package:dio/dio.dart';
import 'package:finsight/core/network/network_providers.dart';
import 'package:finsight/features/purchases/presentation/add_purchase_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackend {
  _FakeBackend({
    List<Map<String, dynamic>> cards = const [],
    List<Map<String, dynamic>> categories = const [],
    List<Map<String, dynamic>> accounts = const [],
  }) : _cards = List.of(cards),
       _categories = List.of(categories),
       _accounts = List.of(accounts);

  final List<Map<String, dynamic>> _cards;
  final List<Map<String, dynamic>> _categories;
  final List<Map<String, dynamic>> _accounts;
  Map<String, dynamic>? lastPurchasePosted;
  int _nextCategoryId = 1;
  int _nextCardId = 1;

  Dio buildDio() {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/cards' && options.method == 'GET') {
            return handler.resolve(
              Response(requestOptions: options, data: _cards, statusCode: 200),
            );
          }
          if (options.path == '/cards' && options.method == 'POST') {
            final body = options.data as Map<String, dynamic>;
            final created = {
              'id': 'card-new-${_nextCardId++}',
              'name': body['name'],
              'brand': null,
              'creditLimit': body['creditLimit'],
              'closingDay': body['closingDay'],
              'dueDay': body['dueDay'],
              'defaultPaymentAccountId': body['defaultPaymentAccountId'],
            };
            _cards.add(created);
            return handler.resolve(
              Response(requestOptions: options, data: created, statusCode: 201),
            );
          }
          if (options.path == '/accounts' && options.method == 'GET') {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: _accounts,
                statusCode: 200,
              ),
            );
          }
          if (options.path == '/categories' && options.method == 'GET') {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: _categories,
                statusCode: 200,
              ),
            );
          }
          if (options.path == '/categories' && options.method == 'POST') {
            final body = options.data as Map<String, dynamic>;
            final created = {
              'id': 'cat-${_nextCategoryId++}',
              'name': body['name'],
              'color': body['color'],
            };
            _categories.add(created);
            return handler.resolve(
              Response(requestOptions: options, data: created, statusCode: 201),
            );
          }
          if (options.path == '/purchases' && options.method == 'POST') {
            lastPurchasePosted = options.data as Map<String, dynamic>;
            return handler.resolve(
              Response(
                requestOptions: options,
                data: {'id': 'purchase-1', 'installments': []},
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
    return dio;
  }
}

void main() {
  const oneCard = [
    {
      'id': 'card-1',
      'name': 'Nubank',
      'brand': null,
      'creditLimit': '5000.00',
      'closingDay': 10,
      'dueDay': 17,
      'defaultPaymentAccountId': 'acc-1',
    },
  ];

  Future<void> pumpSheet(WidgetTester tester, _FakeBackend backend) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(backend.buildDio())],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showAddPurchaseSheet(context),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('BRL mask formats the amount as the user types', (
    WidgetTester tester,
  ) async {
    await pumpSheet(tester, _FakeBackend(cards: oneCard));

    await tester.enterText(find.byType(TextField).first, '250090');
    await tester.pump();

    expect(find.text('2.500,90'), findsOneWidget);
  });

  testWidgets(
    'creating a tag inline from the purchase form works the same way',
    (WidgetTester tester) async {
      await pumpSheet(
        tester,
        _FakeBackend(cards: oneCard, categories: const []),
      );

      await tester.tap(find.text('tags'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar ou criar uma tag'),
        'Streaming',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Criar tag "Streaming"'));
      await tester.pumpAndSettle();

      expect(find.text('Streaming'), findsOneWidget);
    },
  );

  testWidgets(
    'choosing "novo cartão" with no cards cadastrados creates one inline and selects it',
    (WidgetTester tester) async {
      const oneAccount = [
        {
          'id': 'acc-1',
          'name': 'Conta Principal',
          'type': 'checking',
          'initialBalance': '0.00',
        },
      ];
      final backend = _FakeBackend(cards: const [], accounts: oneAccount);
      await pumpSheet(tester, backend);

      await tester.tap(find.text('escolher cartão'));
      await tester.pumpAndSettle();

      expect(find.text('novo cartão'), findsOneWidget);
      await tester.tap(find.text('novo cartão'));
      await tester.pumpAndSettle();

      // Lands directly on the "novo cartão" form, no detour through Menu > Cartões.
      expect(find.text('Novo cartão'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Nome (ex: Nubank)'),
        'Inter',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Limite'), '1000');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conta Principal'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      // Back on the purchase form, the newly created card is already selected.
      expect(find.text('Inter'), findsOneWidget);
      expect(find.text('escolher cartão'), findsNothing);
    },
  );

  testWidgets(
    'saving posts the chosen card, masked amount, installments and tag',
    (WidgetTester tester) async {
      final backend = _FakeBackend(
        cards: oneCard,
        categories: const [
          {'id': 'cat-1', 'name': 'Assinaturas', 'color': '#6A3FC7'},
        ],
      );
      await pumpSheet(tester, backend);

      // Pick the card.
      await tester.tap(find.text('escolher cartão'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nubank'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '9990'); // -> 99,90

      // Pick installments.
      await tester.tap(find.text('à vista'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, '3x'));
      await tester.pumpAndSettle();

      // Pick tag.
      await tester.tap(find.text('tags'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assinaturas'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(FilledButton, 'adicionar gasto com cartão'),
      );
      await tester.pumpAndSettle();

      expect(backend.lastPurchasePosted, isNotNull);
      expect(backend.lastPurchasePosted!['cardId'], 'card-1');
      expect(backend.lastPurchasePosted!['amount'], '99.90');
      expect(backend.lastPurchasePosted!['installmentsCount'], 3);
      expect(backend.lastPurchasePosted!['categoryId'], 'cat-1');
    },
  );
}
