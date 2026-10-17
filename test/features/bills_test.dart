import 'package:dio/dio.dart';
import 'package:finsight/core/network/network_providers.dart';
import 'package:finsight/core/notifications/reminder_notifications.dart';
import 'package:finsight/core/notifications/reminder_planner.dart';
import 'package:finsight/core/offline/offline_store.dart';
import 'package:finsight/features/bills/data/bill.dart';
import 'package:finsight/features/bills/presentation/bills_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Bill _bill(
  String id,
  String description,
  String amount,
  DateTime due, {
  bool paid = false,
  BillKind kind = BillKind.recurringSaida,
}) => Bill(
  kind: kind,
  id: id,
  description: description,
  amount: amount,
  dueDate: due,
  paid: paid,
);

class _FakeNotifications implements ReminderNotifications {
  List<PlannedReminder> scheduled = [];
  bool permissionGranted = true;
  int permissionRequests = 0;

  @override
  Future<void> init(void Function(DateTime dueDate) onOpen) async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    scheduled = reminders;
  }

  @override
  Future<void> cancelAll() async => scheduled = [];

  @override
  Future<void> scheduleOne(PlannedReminder reminder) async =>
      scheduled = [...scheduled, reminder];

  @override
  Future<DateTime?> launchDueDate() async => null;
}

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T00:00:00.000Z';

class _FakeBackend {
  _FakeBackend(this.bills);

  final List<Map<String, dynamic>> bills;
  final List<String> patches = [];

  Dio buildDio() {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/bills' && options.method == 'GET') {
            return handler.resolve(
              Response(requestOptions: options, data: bills, statusCode: 200),
            );
          }
          if (options.method == 'PATCH' && options.path.endsWith('/paid')) {
            final paid = (options.data as Map)['paid'] as bool;
            patches.add('${options.path}=$paid');
            final id = options.path.split('/')[2];
            for (final b in bills) {
              if (b['id'] == id) b['paid'] = paid;
            }
            return handler.resolve(
              Response(requestOptions: options, data: {}, statusCode: 200),
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

  group('planReminders', () {
    final now = DateTime(2026, 10, 10, 12);

    test(
      'groups same-day bills into one reminder the day before and one on the day, at 9h',
      () {
        final due = DateTime(2026, 10, 15);
        final reminders = planReminders([
          _bill('a', 'Internet', '100.00', due),
          _bill('b', 'Água', '80.00', due),
          _bill('c', 'Luz', '270.00', due),
        ], now);

        expect(reminders, hasLength(2));
        expect(reminders[0].when, DateTime(2026, 10, 14, 9));
        expect(reminders[0].title, 'Amanhã vencem 3 contas');
        expect(reminders[0].body, contains('Internet, Água, Luz'));
        expect(reminders[0].body, contains('450,00'));
        expect(reminders[1].when, DateTime(2026, 10, 15, 9));
        expect(reminders[1].title, 'Hoje vencem 3 contas');
        expect(reminders.every((r) => r.dueDate == due), isTrue);
      },
    );

    test('skips paid bills and reminders already in the past', () {
      final reminders = planReminders([
        _bill('rent', 'Aluguel', '1500.00', DateTime(2026, 10, 30), paid: true),
        // Due tomorrow: the "day before" reminder (today 9h) already passed.
        _bill('gym', 'Academia', '90.00', DateTime(2026, 10, 11)),
      ], now);

      expect(reminders, hasLength(1));
      expect(reminders.single.when, DateTime(2026, 10, 11, 9));
      expect(reminders.single.title, 'Hoje vence');
      expect(reminders.single.body, contains('Academia'));
    });

    test('ids are stable per date and slot, and the list is capped', () {
      final bills = [
        for (var i = 1; i <= 40; i++)
          _bill(
            '$i',
            'Conta $i',
            '10.00',
            DateTime(2026, 11, 1).add(Duration(days: i)),
          ),
      ];
      final first = planReminders(bills, now);
      final second = planReminders(bills, now);

      expect(first.map((r) => r.id), second.map((r) => r.id));
      expect(first.map((r) => r.id).toSet(), hasLength(first.length));
      expect(first, hasLength(maxPendingReminders));
      // The cap keeps the soonest ones.
      expect(first.first.when, DateTime(2026, 11, 1, 9));
    });
  });

  group('BillsScreen', () {
    late _FakeBackend backend;
    late _FakeNotifications notifications;
    late OfflineStore store;

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(backend.buildDio()),
            reminderNotificationsProvider.overrideWithValue(notifications),
            offlineStoreProvider.overrideWithValue(store),
          ],
          child: const MaterialApp(home: BillsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      backend = _FakeBackend([
        {
          'kind': 'recurring_saida',
          'id': 'late',
          'description': 'Internet',
          'amount': '100.00',
          'dueDate': _iso(today.subtract(const Duration(days: 3))),
          'paid': false,
        },
        {
          'kind': 'recurring_saida',
          'id': 'rent',
          'description': 'Aluguel',
          'amount': '1500.00',
          'dueDate': _iso(today.add(const Duration(days: 2))),
          'paid': false,
        },
        {
          'kind': 'invoice',
          'id': 'inv',
          'description': 'Fatura Nubank',
          'amount': '320.00',
          'dueDate': _iso(today.add(const Duration(days: 20))),
          'paid': false,
        },
      ]);
      notifications = _FakeNotifications();
      store = OfflineStore.memory();
    });

    testWidgets('groups bills and shows overdue ones first', (tester) async {
      await pump(tester);

      expect(find.text('Vencidas sem check'), findsOneWidget);
      expect(find.text('Próximos 7 dias'), findsOneWidget);
      expect(find.text('Mais adiante'), findsOneWidget);
      expect(find.text('Internet'), findsOneWidget);
      expect(find.text('Aluguel'), findsOneWidget);
      expect(find.text('Fatura Nubank'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Internet')).dy,
        lessThan(tester.getTopLeft(find.text('Aluguel')).dy),
      );
    });

    testWidgets('enabling reminders asks permission and schedules unpaid bills', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Ativar'));
      await tester.pumpAndSettle();

      expect(notifications.permissionRequests, 1);
      expect(find.text('Ativar'), findsNothing);
      // Aluguel (in 2 days) and the invoice (in 20) each get "amanhã" + "hoje".
      expect(notifications.scheduled, hasLength(4));
    });

    testWidgets('checking a bill sends it and cancels its reminders', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Ativar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aluguel'));
      await tester.pumpAndSettle();

      expect(backend.patches, ['/transactions/rent/paid=true']);
      expect(notifications.scheduled, hasLength(2));
      expect(
        notifications.scheduled.every((r) => r.body.contains('Fatura Nubank')),
        isTrue,
      );
      final checkbox = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('Aluguel'),
          matching: find.byType(CheckboxListTile),
        ),
      );
      expect(checkbox.value, isTrue);
    });
  });
}
