import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/selected_month_provider.dart';
import '../data/budget_item.dart';
import '../data/budget_repository.dart';

final budgetItemsListProvider = FutureProvider.autoDispose<List<BudgetItem>>((
  ref,
) {
  return ref.watch(budgetRepositoryProvider).list();
});

final budgetSummaryProvider = FutureProvider.autoDispose<BudgetSummary>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return ref
      .watch(budgetRepositoryProvider)
      .summary(year: month.year, month: month.month);
});
