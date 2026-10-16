import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/providers/selected_month_provider.dart';
import '../../reports/data/daily_balance_day.dart';
import '../../reports/data/reports_repository.dart';
import '../data/saldos_column_filter.dart';

final saldosColumnFilterProvider = StateProvider<SaldosColumnFilter>((ref) => SaldosColumnFilter.todas);

final dailyBalanceProvider = FutureProvider.autoDispose<List<DailyBalanceDay>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return ref.watch(reportsRepositoryProvider).dailyBalance(year: month.year, month: month.month);
});
