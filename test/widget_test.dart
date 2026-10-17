import 'package:dio/dio.dart';
import 'package:finsight/core/network/network_providers.dart';
import 'package:finsight/core/storage/token_storage.dart';
import 'package:finsight/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finsight/main.dart';

/// Stands in for the real Keychain-backed storage so widget tests don't hit
/// the flutter_secure_storage platform channel (unavailable outside a device).
class _FakeTokenStorage extends TokenStorage {
  _FakeTokenStorage() : super(const FlutterSecureStorage());

  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> saveAccessToken(String accessToken) async {}

  @override
  Future<void> clear() async {}
}

/// Stands in for the real HTTP-backed auth repository so the login flow can
/// be exercised without a network call.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(super.dio, super.tokenStorage);

  @override
  Future<void> login(String email, String password) async {
    if (email != 'user@example.com' || password != 'correct-password') {
      throw DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 401,
        ),
      );
    }
  }
}

/// A Dio that resolves every request locally with a canned empty payload, so
/// the home shell's real screens (which fire HTTP calls as soon as they
/// mount, since `IndexedStack` builds all tabs up front) don't hit the
/// network or fail the test with unhandled socket exceptions.
Dio _buildFakeDataDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final Object data = switch (options.path) {
          '/reports/monthly-totals' => {
            'entradas': '0.00',
            'saidas': '0.00',
            'diario': '0.00',
            'economia': '0.00',
            'cartao': '0.00',
            'performance': '0.00',
            'custoDeVida': '0.00',
            'rendaExcedeCustoDeVida': true,
            'economizadoPercent': '0.00',
            'diarioMedioRealizado': '0.00',
            'diarioMedioPrevisto': '0.00',
          },
          '/budget-items/summary' => {
            'total': '0.00',
            'days': 30,
            'dailyAverage': '0.00',
          },
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

  testWidgets('shows the login screen when no session is stored', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        ],
        child: const FinSightApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FinSight'), findsWidgets);
    expect(find.widgetWithText(TextFormField, 'E-mail'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Senha'), findsOneWidget);
  });

  testWidgets('wrong credentials show an error and stay on login', (
    WidgetTester tester,
  ) async {
    final tokenStorage = _FakeTokenStorage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(Dio(), tokenStorage),
          ),
        ],
        child: const FinSightApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      'user@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha'),
      'wrong-password',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'E-mail'), findsOneWidget);
  });

  testWidgets('correct credentials navigate to the home shell', (
    WidgetTester tester,
  ) async {
    final tokenStorage = _FakeTokenStorage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(Dio(), tokenStorage),
          ),
          dioProvider.overrideWithValue(_buildFakeDataDio()),
        ],
        child: const FinSightApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      'user@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha'),
      'correct-password',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'E-mail'), findsNothing);
    expect(find.text('Saldos'), findsWidgets);
    expect(find.text('Menu'), findsWidgets);
  });
}
