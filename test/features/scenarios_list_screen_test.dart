import 'package:dio/dio.dart';
import 'package:finsight/core/network/network_providers.dart';
import 'package:finsight/features/scenarios/presentation/scenarios_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'swiping a simulação asks first, then deletes it permanently and removes the row',
    (WidgetTester tester) async {
      final scenarios = [
        {'id': 'scn-1', 'name': 'Notebook', 'status': 'confirmed'},
        {'id': 'scn-2', 'name': 'Viagem', 'status': 'draft'},
      ];
      RequestOptions? deleteRequest;
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'DELETE') {
              deleteRequest = options;
              scenarios.removeWhere((s) => options.path.endsWith(s['id']!));
              return handler.resolve(
                Response(requestOptions: options, statusCode: 204),
              );
            }
            handler.resolve(
              Response(
                requestOptions: options,
                data: [...scenarios],
                statusCode: 200,
              ),
            );
          },
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [dioProvider.overrideWithValue(dio)],
          child: const MaterialApp(home: ScenariosListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Cancelling keeps it.
      await tester.drag(find.text('Notebook'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Excluir simulação?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Notebook'), findsOneWidget);
      expect(deleteRequest, isNull);

      await tester.drag(find.text('Notebook'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      expect(deleteRequest!.path, '/scenarios/scn-1');
      expect(deleteRequest!.queryParameters, {'permanent': 'true'});
      expect(find.text('Notebook'), findsNothing);
      expect(find.text('Viagem'), findsOneWidget);
    },
  );
}
