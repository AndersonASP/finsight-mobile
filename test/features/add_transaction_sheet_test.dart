import 'package:dio/dio.dart';
import 'package:finsight/core/network/network_providers.dart';
import 'package:finsight/features/transactions/data/recurrence_interval.dart';
import 'package:finsight/features/transactions/presentation/add_transaction_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stateful fake Dio: categories created via POST are visible in subsequent
/// GET calls, and the last POST /transactions body is captured for assertions.
class _FakeBackend {
  _FakeBackend({
    List<Map<String, dynamic>> accounts = const [],
    List<Map<String, dynamic>> categories = const [],
  }) : _accounts = List.of(accounts),
       _categories = List.of(categories);

  final List<Map<String, dynamic>> _accounts;
  final List<Map<String, dynamic>> _categories;
  Map<String, dynamic>? lastTransactionPosted;
  Map<String, dynamic>? lastRecurringPosted;
  int _nextCategoryId = 1;
  int _nextAccountId = 1;

  Dio buildDio() {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/accounts' && options.method == 'GET') {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: _accounts,
                statusCode: 200,
              ),
            );
          }
          if (options.path == '/accounts' && options.method == 'POST') {
            final body = options.data as Map<String, dynamic>;
            final created = {
              'id': 'acc-new-${_nextAccountId++}',
              'name': body['name'],
              'type': body['type'],
              'initialBalance': body['initialBalance'] ?? '0.00',
            };
            _accounts.add(created);
            return handler.resolve(
              Response(requestOptions: options, data: created, statusCode: 201),
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
          if (options.path == '/transactions' && options.method == 'POST') {
            lastTransactionPosted = options.data as Map<String, dynamic>;
            final body = lastTransactionPosted!;
            final created = {
              'id': 'tx-1',
              'accountId': body['accountId'],
              'type': body['type'],
              'amount': body['amount'],
              'date': '${body['date']}T00:00:00.000Z',
              'categoryId': body['categoryId'],
              'description': body['description'],
              'counterpartAccountId': body['counterpartAccountId'],
            };
            return handler.resolve(
              Response(requestOptions: options, data: created, statusCode: 201),
            );
          }
          if (options.path == '/recurring-transactions' &&
              options.method == 'POST') {
            lastRecurringPosted = options.data as Map<String, dynamic>;
            return handler.resolve(
              Response(
                requestOptions: options,
                data: {'id': 'recurring-1'},
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
  const oneAccount = [
    {
      'id': 'acc-1',
      'name': 'Conta Principal',
      'type': 'checking',
      'initialBalance': '0.00',
    },
  ];

  const twoAccounts = [
    ...oneAccount,
    {
      'id': 'acc-2',
      'name': 'Carteira',
      'type': 'cash',
      'initialBalance': '0.00',
    },
  ];

  // The Reserva was created first, but the smart default must still prefer
  // the checking account over "whichever account happens to be oldest".
  const reserveCreatedBeforeChecking = [
    {
      'id': 'acc-reserve',
      'name': 'Reserva',
      'type': 'savings_reserve',
      'initialBalance': '0.00',
    },
    {
      'id': 'acc-checking',
      'name': 'Conta Principal',
      'type': 'checking',
      'initialBalance': '0.00',
    },
  ];

  /// Opens the entry point and, since it now shows the type picker first,
  /// taps [initialType] to land on the form — tests that don't care about
  /// the type just get the "saída" default like before.
  Future<void> pumpForm(
    WidgetTester tester,
    _FakeBackend backend, {
    String initialType = 'saída',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(backend.buildDio())],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showAddTransactionEntryPoint(context),
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
    await tester.tap(find.widgetWithText(ListTile, initialType));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the "conta" field defaults silently to the account, with no interaction required to save',
    (WidgetTester tester) async {
      final backend = _FakeBackend(accounts: oneAccount);
      await pumpForm(tester, backend);

      // Shown, defaulted, but never forces a tap before saving.
      expect(find.text('Conta Principal'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '5000'); // -> 50,00
      await tester.tap(find.widgetWithText(FilledButton, 'adicionar saída'));
      await tester.pumpAndSettle();

      expect(backend.lastTransactionPosted!['accountId'], 'acc-1');
    },
  );

  testWidgets('BRL mask formats digits calculator-style as the user types', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester, _FakeBackend(accounts: oneAccount));

    await tester.enterText(find.byType(TextField).first, '12345');
    await tester.pump();

    expect(find.text('12345'), findsNothing); // raw digits never shown
    expect(find.text('123,45'), findsOneWidget);
  });

  testWidgets('tapping the type row switches the lançamento type', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester, _FakeBackend(accounts: oneAccount));

    expect(find.text('saída'), findsOneWidget); // default type

    await tester.tap(find.text('saída'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'entrada'));
    await tester.pumpAndSettle();

    expect(find.text('entrada'), findsOneWidget);
    expect(find.text('saída'), findsNothing);
  });

  testWidgets(
    'transferring economia with no conta reserva cadastrada offers creating one inline',
    (WidgetTester tester) async {
      await pumpForm(tester, _FakeBackend(accounts: oneAccount));

      await tester.tap(find.text('saída'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'economia'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Transferir para outra conta'));
      await tester.pumpAndSettle();

      // No Reserva account exists yet — the dropdown is replaced by a shortcut
      // to create one, instead of showing an empty/dead-end dropdown.
      expect(find.text('criar conta reserva'), findsOneWidget);
      await tester.tap(find.text('criar conta reserva'));
      await tester.pumpAndSettle();

      expect(find.text('Nova conta'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Nome'),
        'Reserva de emergência',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      // Back on the transaction form, the new reserve account is already
      // selected as the transfer destination.
      expect(find.text('Reserva de emergência'), findsOneWidget);
      expect(find.text('criar conta reserva'), findsNothing);
    },
  );

  testWidgets(
    'setting up a recurring lançamento posts to /recurring-transactions with the chosen interval and count',
    (WidgetTester tester) async {
      final backend = _FakeBackend(accounts: oneAccount);
      await pumpForm(tester, backend);

      await tester.enterText(find.byType(TextField).first, '5000'); // -> 50,00

      expect(find.text('não repete'), findsOneWidget);
      await tester.tap(find.text('não repete'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byType(DropdownButtonFormField<RecurrenceInterval?>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quinzenal').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Quantas vezes'),
        '8',
      );
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('quinzenal'), findsOneWidget);
      expect(find.textContaining('8x'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'adicionar saída'));
      await tester.pumpAndSettle();

      expect(backend.lastRecurringPosted, isNotNull);
      expect(backend.lastRecurringPosted!['interval'], 'biweekly');
      expect(backend.lastRecurringPosted!['occurrenceCount'], 8);
      expect(backend.lastRecurringPosted!['isOpenEnded'], false);
      expect(backend.lastRecurringPosted!['amount'], '50.00');
      expect(
        backend.lastTransactionPosted,
        isNull,
      ); // went through the recurring endpoint, not the plain one
    },
  );

  testWidgets(
    '"a perder de vista" sends isOpenEnded without an occurrenceCount',
    (WidgetTester tester) async {
      final backend = _FakeBackend(accounts: oneAccount);
      await pumpForm(tester, backend);

      await tester.enterText(find.byType(TextField).first, '2000'); // -> 20,00

      await tester.tap(find.text('não repete'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byType(DropdownButtonFormField<RecurrenceInterval?>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mensal').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('A perder de vista'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('a perder de vista'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'adicionar saída'));
      await tester.pumpAndSettle();

      expect(backend.lastRecurringPosted, isNotNull);
      expect(backend.lastRecurringPosted!['isOpenEnded'], true);
      expect(
        backend.lastRecurringPosted!.containsKey('occurrenceCount'),
        isFalse,
      );
    },
  );

  testWidgets(
    'the smart default prefers a checking account over an earlier-created Reserva',
    (WidgetTester tester) async {
      final backend = _FakeBackend(accounts: reserveCreatedBeforeChecking);
      await pumpForm(tester, backend);

      expect(
        find.text('Conta Principal'),
        findsOneWidget,
      ); // the checking one, not "Reserva"

      await tester.enterText(find.byType(TextField).first, '5000');
      await tester.tap(find.widgetWithText(FilledButton, 'adicionar saída'));
      await tester.pumpAndSettle();

      expect(backend.lastTransactionPosted!['accountId'], 'acc-checking');
    },
  );

  testWidgets('tapping "conta" lets you switch to another account', (
    WidgetTester tester,
  ) async {
    final backend = _FakeBackend(accounts: twoAccounts);
    await pumpForm(tester, backend);

    expect(find.text('Conta Principal'), findsOneWidget);

    await tester.tap(find.text('Conta Principal'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Carteira'));
    await tester.pumpAndSettle();

    expect(find.text('Carteira'), findsOneWidget);
    expect(find.text('Conta Principal'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '5000');
    await tester.tap(find.widgetWithText(FilledButton, 'adicionar saída'));
    await tester.pumpAndSettle();

    expect(backend.lastTransactionPosted!['accountId'], 'acc-2');
  });

  testWidgets(
    'no account registered yet offers creating one inline instead of a dead-end message',
    (WidgetTester tester) async {
      final backend = _FakeBackend(); // no accounts at all
      await pumpForm(tester, backend);

      expect(
        find.text('Cadastre uma conta primeiro (Menu > Contas).'),
        findsNothing,
      );
      expect(find.text('criar conta'), findsOneWidget);

      await tester.tap(find.text('criar conta'));
      await tester.pumpAndSettle();

      expect(find.text('Nova conta'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Nome'),
        'Conta Principal',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      // Back on the transaction form, the inline button is gone — an account exists now.
      expect(find.text('criar conta'), findsNothing);
    },
  );

  testWidgets(
    'creating a tag that does not exist yet works directly from the tags field',
    (WidgetTester tester) async {
      final backend = _FakeBackend(accounts: oneAccount, categories: const []);
      await pumpForm(tester, backend);

      await tester.tap(find.text('tags'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar ou criar uma tag'),
        'Farmácia',
      );
      await tester.pumpAndSettle();

      expect(find.text('Criar tag "Farmácia"'), findsOneWidget);
      await tester.tap(find.text('Criar tag "Farmácia"'));
      await tester.pumpAndSettle();

      // Color-choosing step now, instead of creating immediately.
      expect(find.text('Cor da tag "Farmácia"'), findsOneWidget);
      await tester.tap(find.text('Criar tag'));
      await tester.pumpAndSettle();

      // Back on the form, the tags row now shows the newly created tag.
      expect(find.text('Farmácia'), findsOneWidget);
      expect(find.text('tags'), findsNothing);
    },
  );

  testWidgets(
    'saving posts the default account id, chosen type, masked amount and tag',
    (WidgetTester tester) async {
      final backend = _FakeBackend(
        accounts: oneAccount,
        categories: const [
          {'id': 'cat-1', 'name': 'Mercado', 'color': '#2E8B57'},
        ],
      );
      await pumpForm(tester, backend);

      await tester.enterText(find.byType(TextField).first, '5000'); // -> 50,00
      await tester.tap(find.text('tags'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mercado'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'adicionar saída'));
      await tester.pumpAndSettle();

      expect(backend.lastTransactionPosted, isNotNull);
      expect(backend.lastTransactionPosted!['accountId'], 'acc-1');
      expect(backend.lastTransactionPosted!['type'], 'saida');
      expect(backend.lastTransactionPosted!['amount'], '50.00');
      expect(backend.lastTransactionPosted!['categoryId'], 'cat-1');
    },
  );
}
