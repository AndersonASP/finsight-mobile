import 'package:dio/dio.dart';
import 'package:finsight/core/network/network_providers.dart';
import 'package:finsight/features/accounts/presentation/accounts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _checkingAccount = {
  'id': 'acc-checking',
  'name': 'Conta corrente',
  'type': 'checking',
  'initialBalance': '0.00',
};
const _reserveAccount = {
  'id': 'acc-reserve',
  'name': 'Reserva',
  'type': 'savings_reserve',
  'initialBalance': '1000.00',
};

/// A fake backend that tracks whether a loan exists yet, so the same sheet
/// can be driven through "pegar emprestado" and then "pagar" in one test.
class _FakeBackend {
  _FakeBackend({this.existingLoan});

  Map<String, dynamic>? existingLoan;
  Map<String, dynamic>? lastLoanPosted;
  Map<String, dynamic>? lastRepaymentPosted;

  Dio buildDio() {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/accounts' && options.method == 'GET') {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: [_checkingAccount, _reserveAccount],
                statusCode: 200,
              ),
            );
          }
          if (options.path.startsWith('/accounts/') &&
              options.path.endsWith('/balance')) {
            final accountId = options.path.split('/')[2];
            final balance = accountId == 'acc-reserve' ? '1000.00' : '0.00';
            return handler.resolve(
              Response(
                requestOptions: options,
                data: {'balance': balance},
                statusCode: 200,
              ),
            );
          }
          if (options.path == '/reserve-loans' && options.method == 'GET') {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: existingLoan == null ? [] : [existingLoan],
                statusCode: 200,
              ),
            );
          }
          if (options.path == '/reserve-loans' && options.method == 'POST') {
            lastLoanPosted = options.data as Map<String, dynamic>;
            final created = {
              'id': 'loan-1',
              'reserveAccountId': lastLoanPosted!['reserveAccountId'],
              'destinationAccountId': lastLoanPosted!['destinationAccountId'],
              'principal': lastLoanPosted!['principal'],
              'borrowDate': '${lastLoanPosted!['borrowDate']}T00:00:00.000Z',
              'monthlyInterestRate': '10',
              'status': 'active',
            };
            existingLoan = created;
            return handler.resolve(
              Response(requestOptions: options, data: created, statusCode: 201),
            );
          }
          if (options.path == '/reserve-loans/loan-1/owed' &&
              options.method == 'GET') {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'outstandingPrincipal': '1000.00',
                  'accruedInterest': '100.00',
                  'totalOwed': '1100.00',
                },
                statusCode: 200,
              ),
            );
          }
          if (options.path == '/reserve-loans/loan-1/repayments' &&
              options.method == 'POST') {
            lastRepaymentPosted = options.data as Map<String, dynamic>;
            return handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'id': 'repayment-1',
                  'repaymentDate':
                      '${lastRepaymentPosted!['repaymentDate']}T00:00:00.000Z',
                  'amount': lastRepaymentPosted!['amount'],
                  'interestPortion': '100.00',
                  'principalPortion': '200.00',
                  'outstandingPrincipalAfter': '800.00',
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
  Future<void> pumpAccounts(WidgetTester tester, _FakeBackend backend) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(backend.buildDio())],
        child: const MaterialApp(home: AccountsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'borrowing from a reserve account posts the principal, destination and date',
    (WidgetTester tester) async {
      final backend = _FakeBackend();
      await pumpAccounts(tester, backend);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.swap_horiz));
      await tester.pumpAndSettle();

      // Defaults to "Pegar empréstimo".
      expect(find.text('Confirmar empréstimo'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).first,
        '50000',
      ); // -> 500,00
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conta corrente').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar empréstimo'));
      await tester.pumpAndSettle();

      expect(backend.lastLoanPosted, isNotNull);
      expect(backend.lastLoanPosted!['reserveAccountId'], 'acc-reserve');
      expect(backend.lastLoanPosted!['destinationAccountId'], 'acc-checking');
      expect(backend.lastLoanPosted!['principal'], '500.00');
    },
  );

  testWidgets(
    'paying back an open loan shows what is owed and posts the repayment amount',
    (WidgetTester tester) async {
      final backend = _FakeBackend(
        existingLoan: {
          'id': 'loan-1',
          'reserveAccountId': 'acc-reserve',
          'destinationAccountId': 'acc-checking',
          'principal': '1000.00',
          'borrowDate': '2026-10-01T00:00:00.000Z',
          'monthlyInterestRate': '10',
          'status': 'active',
        },
      );
      await pumpAccounts(tester, backend);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.swap_horiz));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pagar empréstimo'));
      await tester.pumpAndSettle();

      // The breakdown from GET .../owed is visible before paying.
      expect(find.text('total devido'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField).first,
        '30000',
      ); // -> 300,00
      await tester.tap(find.text('Pagar'));
      await tester.pumpAndSettle();

      expect(backend.lastRepaymentPosted, isNotNull);
      expect(backend.lastRepaymentPosted!['amount'], '300.00');
    },
  );
}
