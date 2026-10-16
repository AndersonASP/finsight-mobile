import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import '../../ledger/data/day_detail_item.dart';
import 'daily_balance_day.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(dioProvider));
});

class ReportsRepository {
  ReportsRepository(this._dio);

  final Dio _dio;

  Future<List<DailyBalanceDay>> dailyBalance({
    required int year,
    required int month,
    String? accountId,
  }) async {
    final response = await _dio.get(
      '/reports/daily-balance',
      queryParameters: {'year': year, 'month': month, 'accountId': ?accountId},
    );
    return (response.data as List)
        .map((json) => DailyBalanceDay.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<MonthlyTotals> monthlyTotals({
    required int year,
    required int month,
  }) async {
    final response = await _dio.get(
      '/reports/monthly-totals',
      queryParameters: {'year': year, 'month': month},
    );
    return MonthlyTotals.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<DayDetailItem>> dayDetail(DateTime date) async {
    final response = await _dio.get(
      '/reports/day-detail',
      queryParameters: {'date': _formatDate(date)},
    );
    return (response.data as List)
        .map((json) => DayDetailItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<CategoryBreakdownItem>> categoryBreakdown({
    required int year,
    required int month,
  }) async {
    final response = await _dio.get(
      '/reports/category-breakdown',
      queryParameters: {'year': year, 'month': month},
    );
    return (response.data as List)
        .map(
          (json) =>
              CategoryBreakdownItem.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<MonthlyTrendPoint>> monthlyTrend({int months = 6}) async {
    final response = await _dio.get(
      '/reports/monthly-trend',
      queryParameters: {'months': months},
    );
    return (response.data as List)
        .map((json) => MonthlyTrendPoint.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<BudgetVsActualItem>> budgetVsActual({
    required int year,
    required int month,
  }) async {
    final response = await _dio.get(
      '/reports/budget-vs-actual',
      queryParameters: {'year': year, 'month': month},
    );
    return (response.data as List)
        .map(
          (json) => BudgetVsActualItem.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
