import 'package:dio/dio.dart';
import 'package:finsight/core/network/network_providers.dart';
import 'package:finsight/features/insights/presentation/savings_capacity_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Map<String, dynamic> _capacity({
  String pode = '640.00',
  String limitadoPor = 'sobra',
  String falta = '360.00',
  bool isPast = false,
}) => {
  'isPast': isPast,
  'entradas': '5000.00',
  'saidas': '2500.00',
  'cartao': '900.00',
  'diarioReal': '600.00',
  'diarioPrevisto': '360.00',
  'economiaFeita': '0.00',
  'sobraProjetada': '640.00',
  'menorSaldoProjetado': '1500.00',
  'folga': '210.00',
  'podeGuardarAgora': pode,
  'limitadoPor': limitadoPor,
  'totalPossivel': pode,
  'percentPossivel': '12.8',
  'metaPercent': '20',
  'metaValor': '1000.00',
  'faltaParaMeta': falta,
  'overspending': [
    {
      'categoryName': 'Delivery',
      'color': '#ff0000',
      'current': '480.00',
      'average': '200.00',
      'excess': '280.00',
    },
  ],
  'destino': {
    'kind': 'reserva',
    'title': 'Reserva de emergência',
    'detail': 'Ela cobre 1,5 meses; o ideal são 6. Faltam 9000.00.',
  },
};

Future<void> _pump(WidgetTester tester, Map<String, dynamic> body) async {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response(requestOptions: options, data: body, statusCode: 200),
      ),
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dioProvider.overrideWithValue(dio)],
      child: MaterialApp(
        home: Scaffold(body: ListView(children: const [SavingsCapacityCard()])),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('shows what can be saved, the gap to the goal and why', (
    tester,
  ) async {
    await _pump(tester, _capacity());

    expect(find.text('Dá para guardar este mês'), findsOneWidget);
    expect(find.textContaining('640,00'), findsOneWidget);
    expect(find.textContaining('13% da renda · meta 20%'), findsOneWidget);
    expect(find.textContaining('faltam'), findsOneWidget);
    expect(find.textContaining('Delivery'), findsOneWidget);
    expect(find.text('Para onde: Reserva de emergência'), findsOneWidget);
    // API decimals rendered as R$.
    expect(find.textContaining('9.000,00'), findsOneWidget);
  });

  testWidgets('explains when the saldo is what holds it back', (tester) async {
    await _pump(tester, _capacity(pode: '0.00', limitadoPor: 'saldo'));
    expect(
      find.textContaining('saldo projetado fica apertado'),
      findsOneWidget,
    );
  });

  testWidgets('tapping shows the step-by-step math', (tester) async {
    await _pump(tester, _capacity());
    await tester.tap(find.text('Dá para guardar este mês'));
    await tester.pumpAndSettle();

    expect(find.text('Como chegamos nesse valor'), findsOneWidget);
    expect(find.text('= Sobra projetada'), findsOneWidget);
    expect(find.text('− Folga de 1 semana de diário'), findsOneWidget);
  });

  testWidgets('stays hidden for a month already over', (tester) async {
    await _pump(tester, _capacity(isPast: true));
    expect(find.text('Dá para guardar este mês'), findsNothing);
  });
}
