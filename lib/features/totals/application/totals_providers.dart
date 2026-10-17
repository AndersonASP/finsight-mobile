import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/selected_month_provider.dart';
import '../../reports/data/daily_balance_day.dart';
import '../../reports/data/reports_repository.dart';

final monthlyTotalsProvider = FutureProvider.autoDispose<MonthlyTotals>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return ref
      .watch(reportsRepositoryProvider)
      .monthlyTotals(year: month.year, month: month.month);
});
