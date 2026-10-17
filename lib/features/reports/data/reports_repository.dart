import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/offline/offline_store.dart';
import '../../ledger/data/day_detail_item.dart';
import 'daily_balance_day.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(
    ref.watch(dioProvider),
    ref.watch(offlineStoreProvider),
  );
});

class ReportsRepository {
  ReportsRepository(this._dio, this._store);

  final Dio _dio;
  final OfflineStore _store;

  static String _dailyBalanceKey(int year, int month) =>
      'dailyBalance.${monthKey(year, month)}';
  static String _dayDetailKey(DateTime date) => 'dayDetail.${dateKey(date)}';

  Future<List<DailyBalanceDay>> dailyBalance({
    required int year,
    required int month,
    String? accountId,
  }) async {
    final response = await _dio.get(
      '/reports/daily-balance',
      queryParameters: {'year': year, 'month': month, 'accountId': ?accountId},
    );
    // Only the consolidated view (what the Saldos tab shows) is cached.
    if (accountId == null) {
      _store.write(_dailyBalanceKey(year, month), {
        'fetchedAt': DateTime.now().toIso8601String(),
        'days': response.data,
      });
    }
    return _parseDailyBalance(response.data as List);
  }

  /// The last consolidated Saldos table fetched for this month, or null.
  List<DailyBalanceDay>? cachedDailyBalance({
    required int year,
    required int month,
  }) {
    final entry = _store.read(_dailyBalanceKey(year, month));
    if (entry is! Map) return null;
    return _parseDailyBalance(entry['days'] as List);
  }

  DateTime? cachedDailyBalanceFetchedAt({
    required int year,
    required int month,
  }) {
    final entry = _store.read(_dailyBalanceKey(year, month));
    if (entry is! Map) return null;
    return DateTime.tryParse(entry['fetchedAt'] as String? ?? '');
  }

  /// Every month that has a cached Saldos table, as first-of-month dates.
  List<DateTime> cachedDailyBalanceMonths() {
    return _store.keysStartingWith('dailyBalance.').map((key) {
      final parts = key.substring('dailyBalance.'.length).split('-');
      return DateTime(int.parse(parts[0]), int.parse(parts[1]));
    }).toList()..sort();
  }

  void removeCachedMonth(DateTime month) {
    _store.remove(_dailyBalanceKey(month.year, month.month));
    final first = DateTime(month.year, month.month);
    final last = DateTime(month.year, month.month + 1, 0);
    for (
      var d = first;
      !d.isAfter(last);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      _store.remove(_dayDetailKey(d));
    }
  }

  List<DailyBalanceDay> _parseDailyBalance(List data) => data
      .map((json) => DailyBalanceDay.fromJson(json as Map<String, dynamic>))
      .toList();

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
    _store.write(_dayDetailKey(date), response.data);
    return _parseDayDetail(response.data as List);
  }

  /// Fetches every day's line items in [from]..[to] (inclusive) in one
  /// request and caches each day separately — so any day of a month the
  /// user has looked at can be opened later without a connection.
  Future<void> prefetchDayDetailRange(DateTime from, DateTime to) async {
    final response = await _dio.get(
      '/reports/day-detail',
      queryParameters: {'from': _formatDate(from), 'to': _formatDate(to)},
    );
    final byDay = <String, List<dynamic>>{};
    for (
      var d = from;
      !d.isAfter(to);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      byDay[dateKey(d)] = [];
    }
    for (final item in response.data as List) {
      final key = (item as Map)['date'] as String;
      byDay[key]?.add(item);
    }
    byDay.forEach((key, items) => _store.write('dayDetail.$key', items));
  }

  List<DayDetailItem>? cachedDayDetail(DateTime date) {
    final data = _store.read(_dayDetailKey(date));
    if (data is! List) return null;
    return _parseDayDetail(data);
  }

  List<DayDetailItem> _parseDayDetail(List data) => data
      .map((json) => DayDetailItem.fromJson(json as Map<String, dynamic>))
      .toList();

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

  /// Omitting [month] aggregates the whole [year] instead of a single month.
  Future<List<CardSpendingItem>> cardSpending({
    required int year,
    int? month,
  }) async {
    final response = await _dio.get(
      '/reports/card-spending',
      queryParameters: {'year': year, 'month': ?month},
    );
    return (response.data as List)
        .map((json) => CardSpendingItem.fromJson(json as Map<String, dynamic>))
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
