import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/offline/connectivity.dart';
import '../../../core/providers/selected_month_provider.dart';
import '../../accounts/data/account.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../offline/pending_changes.dart';
import '../../offline/saldos_overlay.dart';
import '../../offline/sync_service.dart';
import '../../reports/data/daily_balance_day.dart';
import '../../reports/data/reports_repository.dart';
import '../data/saldos_column_filter.dart';

final saldosColumnFilterProvider = StateProvider<SaldosColumnFilter>(
  (ref) => SaldosColumnFilter.todas,
);

/// The Saldos table: live from the server when reachable (cached on the
/// device as a side effect), else the last cached copy — either way with
/// lançamentos not yet synced applied on top (see saldos_overlay.dart).
final dailyBalanceProvider = FutureProvider.autoDispose<List<DailyBalanceDay>>((
  ref,
) async {
  final month = ref.watch(selectedMonthProvider);
  ref.watch(connectivityProvider);
  ref.watch(pendingChangesProvider);
  final repository = ref.watch(reportsRepositoryProvider);

  var fetchedLive = false;
  final base = await networkOrCache(
    ref,
    network: () async {
      final days = await repository.dailyBalance(
        year: month.year,
        month: month.month,
      );
      fetchedLive = true;
      return days;
    },
    cache: () =>
        repository.cachedDailyBalance(year: month.year, month: month.month),
  );
  if (fetchedLive) ref.read(syncServiceProvider).onMonthFetched(month);

  final accounts = ref.read(accountsRepositoryProvider).cachedList() ?? [];
  return applyPendingToDailyBalance(
    base: base,
    year: month.year,
    month: month.month,
    // Read after the await: a sync that finished meanwhile is already
    // reflected in `base` and gone from the queue.
    pending: ref.read(pendingChangesProvider),
    accountTypes: <String, AccountType>{for (final a in accounts) a.id: a.type},
    baseForMonth: (year, month) =>
        repository.cachedDailyBalance(year: year, month: month),
  );
});
