import 'package:dio/dio.dart';
import 'package:finsight/core/network/network_providers.dart';
import 'package:finsight/core/notifications/reminder_notifications.dart';
import 'package:finsight/core/notifications/reminder_planner.dart';
import 'package:finsight/features/what_if/application/what_if_providers.dart';
import 'package:finsight/features/what_if/data/what_if.dart';
import 'package:finsight/features/what_if/presentation/what_if_result_view.dart';
import 'package:finsight/features/what_if/presentation/what_if_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Map<String, dynamic> _option({
  String forma = 'cartao',
  String nome = 'Nubank',
  int parcelas = 2,
  String veredito = 'cabe',
}) => {
  'forma': forma,
  'cardId': forma == 'cartao' ? 'card-1' : null,
  'nome': nome,
  'parcelas': parcelas,
  'valorTotal': '9000.00',
  'valorParcela': parcelas == 2 ? '4500.00' : '9000.00',
  'veredito': veredito,
  'meses': [
    {
      'mes': '2026-11',
      'pagaNoMes': '4500.00',
      'menorSaldoDepois': {'data': '2026-11-08', 'valor': '5500.00'},
      'guardaAntes': '10000.00',
      'guardaDepois': '5500.00',
      'meta': '2000.00',
      'ficaAbaixoDaMeta': false,
      'ficaNegativo': false,
    },
  ],
};

Map<String, dynamic> _result({
  String veredito = 'cabe',
  bool decidido = true,
}) => {
  'descricao': 'Bike',
  'valor': '9000.00',
  'recorrente': false,
  'decidido': decidido,
  'veredito': veredito,
  'manchete': 'Pode comprar. Melhor no Nubank em 2x de R\$ 4.500.',
  'motivos': [
    'A primeira parcela vence em 8/nov: o dinheiro fica com você por mais 21 dias.',
    'No Pix seu saldo cairia para R\$ 1.000 em 18/out.',
  ],
  'caminhos': veredito == 'cabe'
      ? []
      : ['Ou junte para ela: R\$ 4.500/mês além da sua meta, pronta em novembro.'],
  'escolhida': _option(veredito: veredito),
  'opcoes': [
    _option(veredito: veredito),
    _option(
      forma: 'pix',
      nome: 'Pix/débito',
      parcelas: 1,
      veredito: 'fura_reserva',
    ),
  ],
  'metaPercent': '20',
  'reserva': {
    'saldo': '12000.00',
    'meses': '2.5',
    'metaMeses': 6,
    'completa': false,
    'vemPrimeiro': true,
  },
  'traducao': {'diasDeDiario': '45', 'percentDaEntrada': '60'},
};

class _FakeNotifications implements ReminderNotifications {
  int permissionRequests = 0;

  @override
  Future<void> init(void Function(DateTime dueDate) onOpen) async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> scheduleOne(PlannedReminder reminder) async {}

  @override
  Future<DateTime?> launchDueDate() async => null;

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {}
}

WishlistItem _item(String id, String veredito) => WishlistItem.fromJson({
  'id': id,
  'description': 'Bike',
  'amount': '9000.00',
  'pixDiscountPercent': null,
  'interestFreeInstallments': 3,
  'simulacao': _result(veredito: veredito),
});

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('simulates, shows the answer and saves to Quero comprar', (
    tester,
  ) async {
    final requests = <RequestOptions>[];
    final notifications = _FakeNotifications();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final data = switch (options.path) {
            '/cards' => [
              {
                'id': 'card-1',
                'name': 'Nubank',
                'closingDay': 1,
                'dueDay': 8,
                'defaultPaymentAccountId': 'acc-1',
              },
            ],
            '/insights/what-if' => _result(),
            '/wishlist' => {'id': 'w-1'},
            _ => <String, dynamic>{},
          };
          handler.resolve(
            Response(requestOptions: options, data: data, statusCode: 200),
          );
        },
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          reminderNotificationsProvider.overrideWithValue(notifications),
        ],
        child: const MaterialApp(home: WhatIfScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Bike');
    await tester.enterText(find.byType(TextField).at(1), '900000');
    expect(find.text('Nubank'), findsOneWidget); // card chip
    await tester.tap(find.text('Simular'));
    await tester.pumpAndSettle();

    final simulate = requests.firstWhere((r) => r.path == '/insights/what-if');
    expect(simulate.data, {
      'amount': '9000.00',
      'description': 'Bike',
      'payment': {'method': 'decide'},
      'interestFreeInstallments': 1,
    });
    expect(
      find.text('Pode comprar. Melhor no Nubank em 2x de R\$ 4.500.'),
      findsOneWidget,
    );
    final scrollable = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('No Pix seu saldo cairia para R\$ 1.000 em 18/out.'),
      200,
      scrollable: scrollable,
    );
    await tester.scrollUntilVisible(
      find.text('Opções comparadas'),
      200,
      scrollable: scrollable,
    );
    expect(find.text('Fura a reserva'), findsOneWidget);

    // The actions stay pinned under the result.
    await tester.tap(find.text('Salvar em Quero comprar'));
    await tester.pumpAndSettle();
    final save = requests.firstWhere(
      (r) => r.path == '/wishlist' && r.method == 'POST',
    );
    expect(save.data, {
      'description': 'Bike',
      'amount': '9000.00',
      'interestFreeInstallments': 1,
    });
    expect(find.text('Em Quero comprar'), findsOneWidget);
    // The "agora cabe" alert needs permission: asked when saving.
    expect(notifications.permissionRequests, 1);
  });

  test('notifies only when a known item turns "cabe"', () {
    final (nowFits, next) = WishlistWatcher.transitions(
      {'a': 'furaReserva', 'b': 'cabe'},
      [_item('a', 'cabe'), _item('b', 'cabe'), _item('c', 'cabe')],
    );
    expect(nowFits.map((i) => i.id), ['a']); // c is new, b already fit
    expect(next, {'a': 'cabe', 'b': 'cabe', 'c': 'cabe'});
  });

  testWidgets('shows what it takes to buy when it does not fit', (
    tester,
  ) async {
    final json = _result(veredito: 'nao_cabe')
      ..['plano'] = {
        'linhas': [
          'Agora: R\$ 2.433 para tirar o saldo do vermelho até 31/out — esse buraco já existe sem a compra.',
          'Ao todo: R\$ 3.575/mês a menos de gastos (ou a mais de entrada) durante 10 meses.',
        ],
        'buraco': {'valor': '2432.91', 'data': '2026-10-31'},
        'ajusteMensal': '2876.00',
        'compraPorMes': '699.00',
        'meses': 10,
        'porMes': '3575.00',
      };
    await tester.pumpWidget(
      MaterialApp(
        home: WhatIfResultScreen(result: WhatIfResult.fromJson(json)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('O que você precisa'), findsOneWidget);
    expect(
      find.textContaining('para tirar o saldo do vermelho', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('3.575', findRichText: true), findsWidgets);
  });
}
