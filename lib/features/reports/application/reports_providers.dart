import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/daily_balance_day.dart';
import '../data/reports_repository.dart';

/// Shared "mês selecionado" cursor for the two per-month detailed reports
/// (category breakdown, orçado x realizado) — its own provider rather than
/// reusing `selectedMonthProvider` from the Saldos tab, since navigating
/// months in a report shouldn't also move the Saldos/Totais view underneath.
final reportsSelectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final categoryBreakdownProvider =
    FutureProvider.autoDispose<List<CategoryBreakdownItem>>((ref) {
      final month = ref.watch(reportsSelectedMonthProvider);
      return ref
          .watch(reportsRepositoryProvider)
          .categoryBreakdown(year: month.year, month: month.month);
    });

/// Whether the card-spending report shows one month or the whole year it
/// belongs to — its own toggle, independent of `reportsSelectedMonthProvider`
/// (which still supplies the year, and the month when not annual).
final cardSpendingShowAnnualProvider = StateProvider<bool>((ref) => false);

final cardSpendingProvider = FutureProvider.autoDispose<List<CardSpendingItem>>(
  (ref) {
    final month = ref.watch(reportsSelectedMonthProvider);
    final showAnnual = ref.watch(cardSpendingShowAnnualProvider);
    return ref
        .watch(reportsRepositoryProvider)
        .cardSpending(year: month.year, month: showAnnual ? null : month.month);
  },
);

final monthlyTrendProvider =
    FutureProvider.autoDispose<List<MonthlyTrendPoint>>((ref) {
      return ref.watch(reportsRepositoryProvider).monthlyTrend(months: 6);
    });

final budgetVsActualProvider =
    FutureProvider.autoDispose<List<BudgetVsActualItem>>((ref) {
      final month = ref.watch(reportsSelectedMonthProvider);
      return ref
          .watch(reportsRepositoryProvider)
          .budgetVsActual(year: month.year, month: month.month);
    });
