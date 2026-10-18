import 'package:dio/dio.dart';
import 'package:finsight/core/network/network_providers.dart';
import 'package:finsight/core/offline/offline_store.dart';
import 'package:finsight/features/wealth/presentation/wealth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

String _daysAgo(int n) => DateTime.now()
    .subtract(Duration(days: n))
    .toIso8601String()
    .substring(0, 10);

Map<String, dynamic> _summary() => {
  'netWorth': '18200.00',
  'financialNetWorth': '15000.00',
  'totalAssets': '35950.00',
  'totalLiabilities': '17750.00',
  'previousNetWorth': '17000.00',
  'reserveMonths': '2.4',
  'averageMonthlyCost': '2500.00',
  'reserveLoansOwed': '0.00',
  'staleCount': 1,
  'diagnostico': {
    'tendencia': 'caindo',
    'variacao': '-300.00',
    'base': 'historico',
    'desde': {'year': 2026, 'month': 9},
    'jurosMensais': '240.00',
    'dividaCara': '2000.00',
    'reserva': '0.00',
    'disponivelNegativo': false,
  },
  'assets': [
    {
      'group': 'disponivel',
      'label': 'Disponível',
      'total': '1950.00',
      'items': [
        {
          'id': 'acc-1',
          'kind': 'account',
          'name': 'Conta Itaú',
          'value': '1950.00',
          'source': 'calculado',
          'asOf': _daysAgo(0),
          'stale': false,
          'note': 'Pelos lançamentos',
        },
      ],
    },
    {
      'group': 'investimentos',
      'label': 'Investimentos',
      'total': '34000.00',
      'items': [
        {
          'id': 'inv-1',
          'kind': 'account',
          'name': 'Tesouro Selic',
          'value': '34000.00',
          'source': 'informado',
          'asOf': _daysAgo(45),
          'stale': true,
          'note': 'Último valor informado',
        },
      ],
    },
  ],
  'liabilities': [
    {
      'group': 'parcela_fixa',
      'label': 'Parcelados e financiamentos',
      'total': '15750.00',
      'items': [
        {
          'id': 'debt-1',
          'kind': 'debt',
          'name': 'Consignado',
          'value': '15750.00',
          'source': 'calculado',
          'asOf': _daysAgo(0),
          'stale': false,
          'note': '35 parcelas restantes',
          'details': {
            'debtKind': 'parcela_fixa',
            'installmentsPaid': 13,
            'installmentsTotal': 48,
            'endDate': '2029-09-10',
            'monthlyInterestCost': null,
          },
        },
      ],
    },
    {
      'group': 'saldo_variavel',
      'label': 'Saldos devedores',
      'total': '2000.00',
      'items': [
        {
          'id': 'debt-2',
          'kind': 'debt',
          'name': 'Rotativo',
          'value': '2000.00',
          'source': 'informado',
          'asOf': _daysAgo(3),
          'stale': false,
          'note': 'Saldo informado',
          'details': {
            'debtKind': 'saldo_variavel',
            'monthlyInterestCost': '240.00',
          },
        },
      ],
    },
  ],
};

class _FakeBackend {
  final List<String> requests = [];

  Dio buildDio() {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(
            '${options.method} ${options.path} ${options.data ?? ''}',
          );
          Object? data = <dynamic>[];
          if (options.path == '/wealth') data = _summary();
          if (options.method != 'GET') data = <String, dynamic>{};
          handler.resolve(
            Response(requestOptions: options, data: data, statusCode: 200),
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

  late _FakeBackend backend;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(backend.buildDio()),
          offlineStoreProvider.overrideWithValue(OfflineStore.memory()),
        ],
        child: const MaterialApp(home: WealthScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => backend = _FakeBackend());

  testWidgets(
    'leads with the richer/poorer verdict, then net worth, reserve and both sides',
    (tester) async {
      await pump(tester);

      expect(find.text('Você está ficando mais pobre'), findsOneWidget);
      expect(find.textContaining('300,00'), findsOneWidget);
      expect(find.text('desde setembro'), findsOneWidget);
      expect(find.textContaining('240,00 por mês só de juros'), findsOneWidget);
      expect(find.textContaining('15.000,00'), findsOneWidget);
      expect(find.textContaining('18.200,00'), findsOneWidget);
      expect(find.textContaining('2,4 meses'), findsOneWidget);
      expect(find.text('O que você tem'), findsOneWidget);
      expect(find.text('O que você deve'), findsOneWidget);
    },
  );

  testWidgets('says where each number comes from', (tester) async {
    await pump(tester);

    expect(find.textContaining('Pelos lançamentos'), findsOneWidget);
    expect(find.textContaining('informado há 45 dias'), findsOneWidget);
    expect(find.textContaining('13/48 parcelas pagas'), findsOneWidget);
    expect(find.textContaining('240,00/mês de juros'), findsOneWidget);
    expect(find.text('1 valor desatualizado'), findsOneWidget);
  });

  testWidgets('"atualizar valores" walks the informed items, stale first', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('1 valor desatualizado'));
    await tester.pumpAndSettle();

    // Stale investment first, then the variable debt; fixed debts never.
    expect(find.text('1 de 2'), findsOneWidget);
    expect(find.text('Tesouro Selic'), findsWidgets);
    await tester.enterText(find.byType(TextField).last, '3550000');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('2 de 2'), findsOneWidget);
    await tester.tap(find.text('Pular'));
    await tester.pumpAndSettle();

    final posts = backend.requests.where((r) => r.startsWith('POST')).toList();
    expect(posts, hasLength(1));
    expect(posts.single, contains('/accounts/inv-1/balance-snapshots'));
    expect(posts.single, contains('35500.00'));
    expect(backend.requests.any((r) => r.startsWith('PATCH')), isFalse);
  });

  testWidgets('a new fixed-installment debt is described as "parcela X de Y"', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Adicionar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dívida'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Banco X');
    await tester.enterText(fields.at(1), '45000'); // parcela R$ 450,00
    await tester.enterText(fields.at(2), '13');
    await tester.enterText(fields.at(3), '48');
    await tester.enterText(fields.at(4), '10');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final post = backend.requests.singleWhere(
      (r) => r.startsWith('POST /debts'),
    );
    expect(post, contains('kind: parcela_fixa'));
    expect(post, contains('installmentAmount: 450.00'));
    expect(post, contains('currentInstallment: 13'));
    expect(post, contains('installmentsTotal: 48'));
    expect(post, contains('installmentDueDay: 10'));
  });
}
