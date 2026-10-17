import 'package:dio/dio.dart';
import 'package:finsight/core/network/network_providers.dart';
import 'package:finsight/core/offline/offline_store.dart';
import 'package:finsight/features/ledger/application/ledger_providers.dart';
import 'package:finsight/features/offline/live_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'refetches screen data only when the server data version moves',
    () async {
      var version = 1;
      var dailyBalanceFetches = 0;
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            Object data = <dynamic>[];
            if (options.path == '/sync/version') data = {'version': version};
            if (options.path == '/reports/daily-balance') dailyBalanceFetches++;
            handler.resolve(
              Response(requestOptions: options, data: data, statusCode: 200),
            );
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(dio),
          offlineStoreProvider.overrideWithValue(OfflineStore.memory()),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(dailyBalanceProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(dailyBalanceProvider.future);
      expect(dailyBalanceFetches, 1);

      final live = container.read(liveRefreshProvider);
      await live.check(); // first check only learns the version
      await live.check(); // unchanged
      await container.read(dailyBalanceProvider.future);
      expect(dailyBalanceFetches, 1);

      version = 2; // e.g. Claude added a lançamento through the MCP
      await live.check();
      await container.read(dailyBalanceProvider.future);
      expect(dailyBalanceFetches, 2);
    },
  );
}
