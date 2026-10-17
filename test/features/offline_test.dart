import 'package:dio/dio.dart';
import 'package:finsight/core/format/money.dart';
import 'package:finsight/core/network/network_providers.dart';
import 'package:finsight/core/offline/offline_store.dart';
import 'package:finsight/features/accounts/data/account.dart';
import 'package:finsight/features/ledger/application/ledger_providers.dart';
import 'package:finsight/features/ledger/presentation/saldos_screen.dart';
import 'package:finsight/features/offline/pending_changes.dart';
import 'package:finsight/features/offline/saldos_overlay.dart';
import 'package:finsight/features/reports/data/daily_balance_day.dart';
import 'package:finsight/features/transactions/data/fin_transaction.dart';
import 'package:finsight/features/transactions/data/transaction_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

DailyBalanceDay _day(
  int day,
  String saldo, {
  int year = 2026,
  int month = 9,
  String diario = '0.00',
  bool forecast = false,
}) => DailyBalanceDay(
  day: day,
  date: DateTime(year, month, day),
  entrada: '0.00',
  saida: '0.00',
  diario: diario,
  diarioIsForecast: forecast,
  economia: '0.00',
  cartao: '0.00',
  saldo: saldo,
);

FinTransaction _tx(
  String id,
  FinTransactionType type,
  String amount,
  DateTime date, {
  String accountId = 'acc-1',
  String? counterpart,
}) => FinTransaction(
  id: id,
  accountId: accountId,
  type: type,
  amount: amount,
  date: date,
  counterpartAccountId: counterpart,
);

const _types = {
  'acc-1': AccountType.checking,
  'res-1': AccountType.savingsReserve,
};

Map<String, dynamic> _dayJson(int year, int month, int day, String saldo) => {
  'day': day,
  'date':
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
  'entrada': '0.00',
  'saida': '0.00',
  'diario': '0.00',
  'diarioIsForecast': false,
  'economia': '0.00',
  'cartao': '0.00',
  'saldo': saldo,
};

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  group('applyPendingToDailyBalance', () {
    final base = [_day(1, '100.00'), _day(2, '100.00'), _day(3, '100.00')];
    final past = DateTime(2026, 1, 1);

    test(
      'a pending entrada fills its column and shifts saldo from that day on',
      () {
        final result = applyPendingToDailyBalance(
          base: base,
          year: 2026,
          month: 9,
          pending: PendingChanges(
            creates: {
              'local-1': _tx(
                'local-1',
                FinTransactionType.entrada,
                '50.00',
                DateTime(2026, 9, 2),
              ),
            },
          ),
          accountTypes: _types,
          baseForMonth: (_, _) => null,
          todayUtc: DateTime(2026, 12, 1),
        );
        expect(result.map((d) => d.saldo), ['100.00', '150.00', '150.00']);
        expect(result[1].entrada, '50.00');
      },
    );

    test('an edit removes the server version and applies the new one', () {
      final serverVersion = _tx(
        'tx-1',
        FinTransactionType.saida,
        '30.00',
        DateTime(2026, 9, 1),
      );
      final result = applyPendingToDailyBalance(
        base: [
          // the server data already includes the original -30 on day 1
          for (final d in base) _day(d.day, '70.00'),
        ],
        year: 2026,
        month: 9,
        pending: PendingChanges(
          updates: {
            'tx-1': PendingUpdate(
              before: serverVersion,
              after: _tx(
                'tx-1',
                FinTransactionType.saida,
                '10.00',
                DateTime(2026, 9, 3),
              ),
            ),
          },
        ),
        accountTypes: _types,
        baseForMonth: (_, _) => null,
        todayUtc: past,
      );
      expect(result.map((d) => d.saldo), ['100.00', '100.00', '90.00']);
    });

    test(
      'a transfer to a reserve leaves the checking saldo, not added back',
      () {
        final result = applyPendingToDailyBalance(
          base: base,
          year: 2026,
          month: 9,
          pending: PendingChanges(
            creates: {
              'local-1': _tx(
                'local-1',
                FinTransactionType.economia,
                '20.00',
                DateTime(2026, 9, 1),
                counterpart: 'res-1',
              ),
            },
          ),
          accountTypes: _types,
          baseForMonth: (_, _) => null,
          todayUtc: past,
        );
        expect(result.first.saldo, '80.00');
        expect(result.first.economia, '20.00');
      },
    );

    test('a real diário on a future day replaces that day\'s forecast', () {
      final forecastBase = [
        _day(1, '90.00', diario: '10.00', forecast: true),
        _day(2, '80.00', diario: '10.00', forecast: true),
      ];
      final result = applyPendingToDailyBalance(
        base: forecastBase,
        year: 2026,
        month: 9,
        pending: PendingChanges(
          creates: {
            'local-1': _tx(
              'local-1',
              FinTransactionType.diario,
              '25.00',
              DateTime(2026, 9, 1),
            ),
          },
        ),
        accountTypes: _types,
        baseForMonth: (_, _) => null,
        todayUtc: DateTime(2026, 8, 1),
      );
      // forecast -10 replaced by real -25 → 15 less, carried to day 2
      expect(result.map((d) => d.saldo), ['75.00', '65.00']);
      expect(result.first.diario, '25.00');
      expect(result.first.diarioIsForecast, isFalse);
      expect(result.last.diarioIsForecast, isTrue);
    });

    test(
      'a pending lançamento in an earlier month carries into later months',
      () {
        final result = applyPendingToDailyBalance(
          base: [_day(1, '100.00', month: 10)],
          year: 2026,
          month: 10,
          pending: PendingChanges(
            creates: {
              'local-1': _tx(
                'local-1',
                FinTransactionType.saida,
                '40.00',
                DateTime(2026, 9, 15),
              ),
            },
          ),
          accountTypes: _types,
          baseForMonth: (_, _) => null,
          todayUtc: past,
        );
        expect(result.single.saldo, '60.00');
        expect(result.single.saida, '0.00');
      },
    );
  });

  group('PendingChangesNotifier', () {
    test('deleting an offline-created lançamento just drops it', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(pendingChangesProvider.notifier);
      final created = _tx(
        newLocalTransactionId(),
        FinTransactionType.saida,
        '5.00',
        DateTime(2026, 9, 1),
      );
      notifier.create(created);
      notifier.delete(created);
      expect(container.read(pendingChangesProvider).isEmpty, isTrue);
    });

    test(
      'deleting an edited server lançamento remembers the server version',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(pendingChangesProvider.notifier);
        final server = _tx(
          'tx-1',
          FinTransactionType.saida,
          '5.00',
          DateTime(2026, 9, 1),
        );
        final edited = _tx(
          'tx-1',
          FinTransactionType.saida,
          '9.00',
          DateTime(2026, 9, 1),
        );
        notifier.edit(serverVersion: server, updated: edited);
        notifier.delete(edited);
        final state = container.read(pendingChangesProvider);
        expect(state.updates, isEmpty);
        expect(state.deletes['tx-1']!.amount, '5.00');
      },
    );

    test('the queue survives a restart (persisted in the offline store)', () {
      final store = OfflineStore.memory();
      final first = ProviderContainer(
        overrides: [offlineStoreProvider.overrideWithValue(store)],
      );
      first
          .read(pendingChangesProvider.notifier)
          .create(
            _tx(
              'local-1',
              FinTransactionType.entrada,
              '1.00',
              DateTime(2026, 9, 1),
            ),
          );
      first.dispose();

      final second = ProviderContainer(
        overrides: [offlineStoreProvider.overrideWithValue(store)],
      );
      addTearDown(second.dispose);
      expect(second.read(pendingChangesProvider).creates.keys, ['local-1']);
    });
  });

  testWidgets(
    'offline: Saldos shows the cached table, a new lançamento is queued and '
    'applied locally, then sent once the connection is back',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final days = [
        _dayJson(now.year, now.month, 1, '1000.00'),
        _dayJson(now.year, now.month, 2, '1000.00'),
      ];
      var offline = false;
      final posted = <Map<String, dynamic>>[];
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (offline) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                ),
              );
            }
            Object data = <dynamic>[];
            if (options.path == '/reports/daily-balance') {
              data = options.queryParameters['month'] == now.month
                  ? days
                  : <dynamic>[];
            } else if (options.path == '/accounts') {
              data = [
                {
                  'id': 'acc-1',
                  'name': 'Conta corrente',
                  'type': 'checking',
                  'initialBalance': '0.00',
                },
              ];
            } else if (options.path == '/transactions' &&
                options.method == 'POST') {
              final body = options.data as Map<String, dynamic>;
              posted.add(body);
              data = {
                'id': 'tx-${posted.length}',
                ...body,
                'date': '${body['date']}T00:00:00.000Z',
              };
            }
            handler.resolve(
              Response(requestOptions: options, data: data, statusCode: 200),
            );
          },
        ),
      );

      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);

      // Online first: the table (and the account list) get cached.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SaldosScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(formatCurrency('1000.00')), findsNWidgets(2));

      // Lose the connection and reload: still there, from cache.
      offline = true;
      container.invalidate(dailyBalanceProvider);
      await tester.pumpAndSettle();
      expect(find.text(formatCurrency('1000.00')), findsNWidgets(2));
      expect(find.textContaining('Sem conexão'), findsOneWidget);

      // Add an entrada on day 1 while offline.
      await tester.longPress(find.byIcon(Icons.south_west_rounded).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '25000'); // 250,00
      await tester.tap(find.widgetWithText(FilledButton, 'adicionar entrada'));
      await tester.pumpAndSettle();

      expect(posted, isEmpty);
      expect(container.read(pendingChangesProvider).count, 1);
      expect(find.text(formatCurrency('1250.00')), findsNWidgets(2));
      expect(
        find.textContaining('1 alteração aguardando envio'),
        findsOneWidget,
      );

      // Connection back: tapping the banner syncs the queue.
      offline = false;
      await tester.tap(find.textContaining('Sem conexão'));
      await tester.pumpAndSettle();

      expect(posted, hasLength(1));
      expect(posted.single['amount'], '250.00');
      expect(posted.single['type'], 'entrada');
      expect(container.read(pendingChangesProvider).isEmpty, isTrue);
      expect(find.textContaining('aguardando envio'), findsNothing);
    },
  );
}
