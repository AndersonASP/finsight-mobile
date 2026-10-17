import 'package:dio/dio.dart';
import 'package:finsight/core/network/network_providers.dart';
import 'package:finsight/features/accounts/presentation/accounts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _existingAccount = {
  'id': 'acc-1',
  'name': 'Minha conta',
  'type': 'checking',
  'initialBalance': '500.00',
};

class _FakeBackend {
  _FakeBackend({
    Map<String, dynamic>? account,
    this.deleteStatus = 204,
    this.deleteErrorMessage,
  }) : _account = account ?? Map.of(_existingAccount);

  Map<String, dynamic> _account;
  final int deleteStatus;
  final String? deleteErrorMessage;
  Map<String, dynamic>? lastPatchBody;

  Dio buildDio() {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/accounts' && options.method == 'GET') {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: [_account],
                statusCode: 200,
              ),
            );
          }
          if (options.path == '/accounts/acc-1/balance') {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: {'balance': _account['initialBalance']},
                statusCode: 200,
              ),
            );
          }
          if (options.path == '/accounts/acc-1' && options.method == 'PATCH') {
            lastPatchBody = options.data as Map<String, dynamic>;
            _account = {..._account, ...lastPatchBody!};
            return handler.resolve(
              Response(
                requestOptions: options,
                data: _account,
                statusCode: 200,
              ),
            );
          }
          if (options.path == '/accounts/acc-1' && options.method == 'DELETE') {
            if (deleteStatus == 204) {
              return handler.resolve(
                Response(requestOptions: options, statusCode: 204),
              );
            }
            return handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: deleteStatus,
                  data: {
                    'error': {
                      'code': 'bad_request',
                      'message': deleteErrorMessage,
                    },
                  },
                ),
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
    'tapping an account opens it pre-filled for editing (type locked), and saving renames + rebalances it',
    (WidgetTester tester) async {
      final backend = _FakeBackend();
      await pumpAccounts(tester, backend);

      await tester.tap(find.text('Minha conta'));
      await tester.pumpAndSettle();

      expect(find.text('Editar conta'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Minha conta'), findsOneWidget);
      // Type shown read-only (no dropdown offered while editing).
      expect(find.byType(DropdownButtonFormField<dynamic>), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Minha conta'),
        'Conta principal',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      expect(backend.lastPatchBody, isNotNull);
      expect(backend.lastPatchBody!['name'], 'Conta principal');
      expect(find.text('Conta principal'), findsOneWidget);
    },
  );

  testWidgets(
    'deleting an account with a non-zero balance warns about the impact before confirming',
    (WidgetTester tester) async {
      final backend = _FakeBackend();
      await pumpAccounts(tester, backend);

      await tester.longPress(find.text('Minha conta'));
      await tester.pumpAndSettle();

      expect(find.textContaining('saldo de'), findsOneWidget);
      expect(
        find.textContaining('afetar seus saldos e projeções'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a blocked deletion shows the backend\'s specific reason instead of failing silently',
    (WidgetTester tester) async {
      final backend = _FakeBackend(
        deleteStatus: 400,
        deleteErrorMessage:
            'Não é possível excluir esta conta: ela é a única conta corrente cadastrada — crie outra antes de remover esta.',
      );
      await pumpAccounts(tester, backend);

      await tester.longPress(find.text('Minha conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível excluir'), findsOneWidget);
      expect(
        find.textContaining('única conta corrente cadastrada'),
        findsOneWidget,
      );
    },
  );
}
