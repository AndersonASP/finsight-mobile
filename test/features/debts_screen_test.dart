import 'package:dio/dio.dart';
import 'package:finsight/core/network/network_providers.dart';
import 'package:finsight/features/debts/presentation/debts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _checkingAccount = {
  'id': 'acc-checking',
  'name': 'Conta corrente',
  'type': 'checking',
  'initialBalance': '0.00',
};

const _existingDebt = {
  'id': 'debt-1',
  'creditor': 'Banco X',
  'type': 'consignado',
  'status': 'em_dia',
  'currentBalance': '1000.00',
  'originalAmount': '1200.00',
  'installmentAmount': '200.00',
  'installmentDueDay': 10,
  'installmentsTotal': 6,
  'installmentsPaid': 1,
  'notes': null,
};

/// A fake backend that tracks whether a debt exists yet, so the same test
/// suite can drive both "criar dívida" and "registrar pagamento" flows.
class _FakeBackend {
  _FakeBackend({this.existingDebt});

  Map<String, dynamic>? existingDebt;
  Map<String, dynamic>? lastDebtPosted;
  Map<String, dynamic>? lastPaymentPosted;

  Dio buildDio() {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/accounts' && options.method == 'GET') {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: [_checkingAccount],
                statusCode: 200,
              ),
            );
          }
          if (options.path == '/debts' && options.method == 'GET') {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: existingDebt == null ? [] : [existingDebt],
                statusCode: 200,
              ),
            );
          }
          if (options.path == '/debts' && options.method == 'POST') {
            lastDebtPosted = options.data as Map<String, dynamic>;
            final created = {
              'id': 'debt-new',
              'creditor': lastDebtPosted!['creditor'],
              'type': lastDebtPosted!['type'],
              'status': lastDebtPosted!['status'] ?? 'em_dia',
              'currentBalance': lastDebtPosted!['currentBalance'],
              'originalAmount': null,
              'installmentAmount': lastDebtPosted!['installmentAmount'],
              'installmentDueDay': lastDebtPosted!['installmentDueDay'],
              'installmentsTotal': lastDebtPosted!['installmentsTotal'],
              'installmentsPaid': 0,
              'notes': null,
            };
            existingDebt = created;
            return handler.resolve(
              Response(requestOptions: options, data: created, statusCode: 201),
            );
          }
          if (options.path == '/debts/debt-1' && options.method == 'GET') {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: {'debt': existingDebt, 'payments': <dynamic>[]},
                statusCode: 200,
              ),
            );
          }
          if (options.path == '/debts/debt-1/payments' &&
              options.method == 'POST') {
            lastPaymentPosted = options.data as Map<String, dynamic>;
            return handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'id': 'payment-1',
                  'paymentDate':
                      '${lastPaymentPosted!['paymentDate']}T00:00:00.000Z',
                  'amount': lastPaymentPosted!['amount'],
                  'balanceAfter': '800.00',
                  'notes': null,
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
    return dio;
  }
}

void main() {
  Future<void> pumpDebts(WidgetTester tester, _FakeBackend backend) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(backend.buildDio())],
        child: const MaterialApp(home: DebtsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'creating a debt from the empty list posts creditor, type and balance',
    (WidgetTester tester) async {
      final backend = _FakeBackend();
      await pumpDebts(tester, backend);

      expect(find.text('Nenhuma dívida cadastrada ainda.'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Credor (ex: Banco X)'),
        'Banco X',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Saldo devedor atual'),
        '100000', // BRL mask: last 2 digits are centavos -> 1.000,00
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(backend.lastDebtPosted, isNotNull);
      expect(backend.lastDebtPosted!['creditor'], 'Banco X');
      expect(backend.lastDebtPosted!['currentBalance'], '1000.00');
      expect(find.text('Banco X'), findsOneWidget);
    },
  );

  testWidgets(
    'registering a payment from the detail screen posts amount and account',
    (WidgetTester tester) async {
      final backend = _FakeBackend(existingDebt: _existingDebt);
      await pumpDebts(tester, backend);

      await tester.tap(find.text('Banco X'));
      await tester.pumpAndSettle();

      expect(find.text('Consignado'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Valor pago'),
        '20000', // BRL mask: last 2 digits are centavos -> 200,00
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conta corrente').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(backend.lastPaymentPosted, isNotNull);
      expect(backend.lastPaymentPosted!['amount'], '200.00');
      expect(backend.lastPaymentPosted!['accountId'], 'acc-checking');
    },
  );
}
