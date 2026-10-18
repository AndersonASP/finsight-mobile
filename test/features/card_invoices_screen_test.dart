import 'package:dio/dio.dart';
import 'package:finsight/core/network/network_providers.dart';
import 'package:finsight/features/cards/data/fin_card.dart';
import 'package:finsight/features/invoices/presentation/card_invoices_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Map<String, dynamic> _invoice(int year, int month) => {
  'id': 'inv-$year-$month',
  'cardId': 'card-1',
  'periodYear': year,
  'periodMonth': month,
  'closingDate': '$year-${month.toString().padLeft(2, '0')}-01',
  'dueDate': '$year-${month.toString().padLeft(2, '0')}-10',
  'status': 'open',
  'total': '100.00',
};

const _card = {
  'id': 'card-1',
  'name': 'Nubank',
  'brand': null,
  'closingDay': 1,
  'dueDay': 10,
  'defaultPaymentAccountId': 'acc-1',
};

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('invoices show the month name, grouped under a header per year', (
    WidgetTester tester,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response(
            requestOptions: options,
            data: [_invoice(2027, 1), _invoice(2026, 12), _invoice(2026, 11)],
            statusCode: 200,
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: MaterialApp(
          home: CardInvoicesScreen(card: FinCard.fromJson(_card)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2027'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('Janeiro'), findsOneWidget);
    expect(find.text('Dezembro'), findsOneWidget);
    expect(find.text('Novembro'), findsOneWidget);
    expect(find.text('12/2026'), findsNothing);
    // Year header comes before its months.
    expect(
      tester.getTopLeft(find.text('2026')).dy,
      lessThan(tester.getTopLeft(find.text('Dezembro')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Janeiro')).dy,
      lessThan(tester.getTopLeft(find.text('2026')).dy),
    );
  });
}
