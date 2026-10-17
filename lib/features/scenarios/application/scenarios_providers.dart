import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../ledger/data/saldos_column_filter.dart';
import '../../reports/data/daily_balance_day.dart';
import '../data/scenario.dart';
import '../data/scenarios_repository.dart';

final scenariosListProvider = FutureProvider.autoDispose<List<Scenario>>((ref) {
  return ref.watch(scenariosRepositoryProvider).list();
});

final scenarioDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, scenarioId) {
      return ref.watch(scenariosRepositoryProvider).detail(scenarioId);
    });

/// "Mês visível" and "coluna mostrada" for a scenario's own Saldos-style
/// table — independent of the real Saldos tab's own cursors (same reasoning
/// as reports_providers.dart's `reportsSelectedMonthProvider`): only one
/// scenario detail screen is ever open at a time, so a single (non-family)
/// provider is enough.
final scenarioMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final scenarioColumnFilterProvider = StateProvider<SaldosColumnFilter>(
  (ref) => SaldosColumnFilter.todas,
);

final scenarioDailyBalanceProvider = FutureProvider.autoDispose
    .family<List<DailyBalanceDay>, String>((ref, scenarioId) {
      final month = ref.watch(scenarioMonthProvider);
      return ref
          .watch(scenariosRepositoryProvider)
          .dailyBalance(
            scenarioId: scenarioId,
            year: month.year,
            month: month.month,
          );
    });

/// Keyed by scenarioId + date together (a record, since `.family` only
/// takes one argument) — mirrors `dayDetailProvider`'s family-by-date, one
/// level deeper since a day's detail here also depends on which scenario.
final scenarioDayDetailProvider = FutureProvider.autoDispose
    .family<ScenarioDayDetail, (String scenarioId, DateTime date)>((ref, key) {
      return ref.watch(scenariosRepositoryProvider).dayDetail(key.$1, key.$2);
    });

/// Projects 30 days from today — enough to surface near-term deficits without
/// asking the user to pick a date range for a first version of this screen.
final scenarioProjectionProvider = FutureProvider.autoDispose
    .family<ScenarioProjection, String>((ref, scenarioId) {
      final now = DateTime.now();
      return ref
          .watch(scenariosRepositoryProvider)
          .projection(
            scenarioId: scenarioId,
            from: now,
            to: now.add(const Duration(days: 30)),
          );
    });
