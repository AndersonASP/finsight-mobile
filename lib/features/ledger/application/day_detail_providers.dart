import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/offline/connectivity.dart';
import '../../categories/data/categories_repository.dart';
import '../../offline/pending_changes.dart';
import '../../offline/saldos_overlay.dart';
import '../data/day_detail_item.dart';
import '../../reports/data/reports_repository.dart';

/// A day's line items — live, or cached when offline — with lançamentos not
/// yet synced applied on top.
final dayDetailProvider = FutureProvider.autoDispose
    .family<List<DayDetailItem>, DateTime>((ref, date) async {
      ref.watch(connectivityProvider);
      ref.watch(pendingChangesProvider);
      final repository = ref.watch(reportsRepositoryProvider);
      final base = await networkOrCache(
        ref,
        network: () => repository.dayDetail(date),
        // A day never cached can still show what was added offline for it.
        cache: () =>
            repository.cachedDayDetail(date) ??
            (pendingTouchesDate(ref.read(pendingChangesProvider), date)
                ? const <DayDetailItem>[]
                : null),
      );
      return applyPendingToDayDetail(
        base: base,
        date: date,
        pending: ref.read(pendingChangesProvider),
        categories: ref.read(categoriesRepositoryProvider).cachedList() ?? [],
      );
    });
