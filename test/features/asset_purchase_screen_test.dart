import 'package:dio/dio.dart';
import 'package:finsight/core/network/network_providers.dart';
import 'package:finsight/core/offline/offline_store.dart';
import 'package:finsight/features/what_if/presentation/asset_purchase_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _side(String total, String devedor, String pct) => {
  'total': total,
  'saldoDevedor': devedor,
  'liquido': '125000.00',
  'percentLiquido': pct,
  'alertaAbaixoDe40': pct == '32.8',
  'livreEmDinheiro': '0.00',
  'reserva': '100000.00',
  'reservaMeses': '20.0',
  'blocos': {
    'reserva': {'valor': '100000.00', 'percent': '80.0'},
    'investimentos': {'valor': '0.00', 'percent': '0.0'},
    'outros': {'valor': '25000.00', 'percent': '20.0'},
  },
};

class _FakeBackend {
  final List<RequestOptions> posts = [];

  Dio buildDio() {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          Object? data = <dynamic>[];
          if (options.path == '/accounts') {
            data = [
              {
                'id': 'acc-1',
                'name': 'Conta',
                'type': 'checking',
                'initialBalance': '0.00',
              },
            ];
          }
          if (options.method == 'POST') {
            posts.add(options);
            data = {
              'veredito': 'fura_reserva',
              'manchete': 'Apto fura a sua reserva.',
              'linhas': ['Custo real: R\$ 340.000'],
              'custo': {'total': '340000.00'},
              'reserva': {'metaMeses': 8},
              'antes': _side('125000.00', '0.00', '100.0'),
              'depois': _side('381000.00', '256000.00', '32.8'),
            };
          }
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
  testWidgets(
    'simulates with price, taxes, documentation and financing, then shows the patrimônio before/after',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final backend = _FakeBackend();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(backend.buildDio()),
            offlineStoreProvider.overrideWithValue(OfflineStore.memory()),
          ],
          child: const MaterialApp(home: AssetPurchaseScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final amounts = find.byType(TextField);
      await tester.enterText(
        find.widgetWithText(TextField, 'O quê (ex.: Apto)'),
        'Apto',
      );
      // preço, impostos, documentação, entrada, parcelas, valor da parcela
      await tester.enterText(amounts.at(1), '32000000');
      await tester.enterText(amounts.at(2), '1500000');
      await tester.enterText(amounts.at(3), '500000');
      await tester.enterText(amounts.at(4), '8400000');
      await tester.enterText(find.widgetWithText(TextField, 'Parcelas'), '360');
      await tester.enterText(amounts.at(6), '250000');
      await tester.tap(find.text('Simular'));
      await tester.pumpAndSettle();

      final body = backend.posts.single.data as Map<String, dynamic>;
      expect(body['price'], '320000.00');
      expect(body['taxes'], '15000.00');
      expect(body['fees'], '5000.00');
      expect(body['downPayment'], '84000.00');
      expect(body['downPaymentAccountId'], 'acc-1');
      expect(body['financing'], {
        'installments': 360,
        'installmentAmount': '2500.00',
      });

      expect(find.text('Apto fura a sua reserva.'), findsOneWidget);
      expect(find.text('32,8%'), findsOneWidget);
      expect(find.text('Registrar a compra'), findsOneWidget);
    },
  );
}
