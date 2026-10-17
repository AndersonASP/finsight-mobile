import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/offline/connectivity.dart';
import '../data/wealth.dart';
import '../data/wealth_repository.dart';

final wealthSummaryProvider = FutureProvider.autoDispose<WealthSummary>((ref) {
  ref.watch(connectivityProvider);
  final repository = ref.watch(wealthRepositoryProvider);
  return networkOrCache(
    ref,
    network: repository.summary,
    cache: repository.cachedSummary,
  );
});

final wealthHistoryProvider = FutureProvider.autoDispose<List<NetWorthPoint>>((
  ref,
) {
  ref.watch(connectivityProvider);
  final repository = ref.watch(wealthRepositoryProvider);
  return networkOrCache(
    ref,
    network: repository.history,
    cache: repository.cachedHistory,
  );
});

/// After any change that moves the patrimônio.
void refreshWealth(WidgetRef ref) {
  ref.invalidate(wealthSummaryProvider);
  ref.invalidate(wealthHistoryProvider);
}
