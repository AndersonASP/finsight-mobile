import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/offline/offline_store.dart';
import 'bill.dart';

final billsRepositoryProvider = Provider<BillsRepository>((ref) {
  return BillsRepository(
    ref.watch(dioProvider),
    ref.watch(offlineStoreProvider),
  );
});

class BillsRepository {
  BillsRepository(this._dio, this._store);

  final Dio _dio;
  final OfflineStore _store;

  static const _cacheKey = 'bills';

  /// Bills due in [from]..[to] (inclusive). The last response is cached so
  /// the checklist and the reminders keep working offline.
  Future<List<Bill>> list({
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _dio.get(
      '/bills',
      queryParameters: {'from': dateKey(from), 'to': dateKey(to)},
    );
    _store.write(_cacheKey, response.data);
    return _parse(response.data as List);
  }

  List<Bill>? cachedList() {
    final cached = _store.read(_cacheKey);
    return cached is List ? _parse(cached) : null;
  }

  Future<void> setPaid(BillKind kind, String id, bool paid) async {
    await _dio.patch('/${kind.resource}/$id/paid', data: {'paid': paid});
  }

  static List<Bill> _parse(List data) => data
      .map((json) => Bill.fromJson(Map<String, dynamic>.from(json)))
      .toList();
}
