import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/offline/offline_store.dart';
import 'wealth.dart';

final wealthRepositoryProvider = Provider<WealthRepository>((ref) {
  return WealthRepository(
    ref.watch(dioProvider),
    ref.watch(offlineStoreProvider),
  );
});

class WealthRepository {
  WealthRepository(this._dio, this._store);

  final Dio _dio;
  final OfflineStore _store;

  static const _summaryKey = 'wealth';
  static const _historyKey = 'wealth.history';

  /// Cached so the Patrimônio tab still opens offline.
  Future<WealthSummary> summary() async {
    final response = await _dio.get('/wealth');
    _store.write(_summaryKey, response.data);
    return WealthSummary.fromJson(Map<String, dynamic>.from(response.data));
  }

  WealthSummary? cachedSummary() {
    final cached = _store.read(_summaryKey);
    return cached is Map
        ? WealthSummary.fromJson(Map<String, dynamic>.from(cached))
        : null;
  }

  Future<List<NetWorthPoint>> history({int months = 12}) async {
    final response = await _dio.get(
      '/wealth/history',
      queryParameters: {'months': months},
    );
    _store.write(_historyKey, response.data);
    return _parseHistory(response.data as List);
  }

  List<NetWorthPoint>? cachedHistory() {
    final cached = _store.read(_historyKey);
    return cached is List ? _parseHistory(cached) : null;
  }

  /// "Quanto vale hoje" for an investment account (a dated balance snapshot).
  Future<void> updateInvestmentValue(String accountId, String value) async {
    await _dio.post(
      '/accounts/$accountId/balance-snapshots',
      data: {'snapshotDate': dateKey(DateTime.now()), 'balance': value},
    );
  }

  Future<void> saveAsset({
    String? id,
    required String name,
    required AssetKind kind,
    required String value,
    required bool isLiquid,
  }) async {
    final data = {
      'name': name,
      'kind': kind.apiValue,
      'value': value,
      'isLiquid': isLiquid,
    };
    if (id == null) {
      await _dio.post('/assets', data: data);
    } else {
      await _dio.patch('/assets/$id', data: data);
    }
  }

  /// Re-confirms an informed asset's value as of today.
  Future<void> updateAssetValue(String id, String value) async {
    await _dio.patch('/assets/$id', data: {'value': value});
  }

  Future<void> deleteAsset(String id) => _dio.delete('/assets/$id');

  /// New informed balance for a saldo-variável debt.
  Future<void> updateDebtBalance(String id, String value) async {
    await _dio.patch('/debts/$id', data: {'currentBalance': value});
  }

  static List<NetWorthPoint> _parseHistory(List data) => data
      .map((p) => NetWorthPoint.fromJson(Map<String, dynamic>.from(p)))
      .toList();
}
