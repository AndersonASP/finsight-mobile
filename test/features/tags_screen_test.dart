import 'package:dio/dio.dart';
import 'package:finsight/core/network/network_providers.dart';
import 'package:finsight/features/categories/presentation/tags_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _existingCategory = {
  'id': 'cat-1',
  'name': 'Mercado',
  'color': '#1E88E5',
};

class _FakeBackend {
  _FakeBackend({Map<String, dynamic>? category})
    : _category = category ?? Map.of(_existingCategory);

  Map<String, dynamic> _category;
  Map<String, dynamic>? lastPatchBody;

  Dio buildDio() {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/categories' && options.method == 'GET') {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: [_category],
                statusCode: 200,
              ),
            );
          }
          if (options.path == '/categories/cat-1' &&
              options.method == 'PATCH') {
            lastPatchBody = options.data as Map<String, dynamic>;
            _category = {..._category, ...lastPatchBody!};
            return handler.resolve(
              Response(
                requestOptions: options,
                data: _category,
                statusCode: 200,
              ),
            );
          }
          if (options.path == '/categories/cat-1/totals') {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: {'total': '0.00'},
                statusCode: 200,
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
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  Future<void> pumpTags(WidgetTester tester, _FakeBackend backend) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(backend.buildDio())],
        child: const MaterialApp(home: TagsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'tapping an existing tag opens it pre-filled for editing, and saving renames + recolors it',
    (WidgetTester tester) async {
      final backend = _FakeBackend();
      await pumpTags(tester, backend);

      await tester.tap(find.text('Mercado'));
      await tester.pumpAndSettle();

      expect(find.text('Editar tag'), findsOneWidget);
      // Pre-filled with the existing name.
      expect(find.widgetWithText(TextField, 'Mercado'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Supermercado');
      // Pick a different swatch than the current one — scoped to the Wrap so
      // it can't accidentally hit the tag list's own CircleAvatar underneath.
      await tester.tap(
        find
            .descendant(
              of: find.byType(Wrap),
              matching: find.byType(CircleAvatar),
            )
            .first,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      expect(backend.lastPatchBody, isNotNull);
      expect(backend.lastPatchBody!['name'], 'Supermercado');
      expect(backend.lastPatchBody!['color'], isNotNull);
      expect(find.text('Supermercado'), findsOneWidget);
    },
  );
}
