import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/offline/offline_store.dart';
import 'account.dart';
import 'account_balance_history_point.dart';

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return AccountsRepository(
    ref.watch(dioProvider),
    ref.watch(offlineStoreProvider),
  );
});

class AccountsRepository {
  AccountsRepository(this._dio, this._store);

  final Dio _dio;
  final OfflineStore _store;

  static const _cacheKey = 'accounts';

  List<Account>? cachedList() {
    final data = _store.read(_cacheKey);
    if (data is! List) return null;
    return data
        .map((json) => Account.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  Future<List<Account>> list() async {
    final response = await _dio.get('/accounts');
    _store.write(_cacheKey, response.data);
    return (response.data as List)
        .map((json) => Account.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Account> create({
    required String name,
    required AccountType type,
    String initialBalance = '0',
  }) async {
    final response = await _dio.post(
      '/accounts',
      data: {
        'name': name,
        'type': type.apiValue,
        'initialBalance': initialBalance,
      },
    );
    return Account.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Account> update({
    required String id,
    String? name,
    String? initialBalance,
  }) async {
    final response = await _dio.patch(
      '/accounts/$id',
      data: {'name': ?name, 'initialBalance': ?initialBalance},
    );
    return Account.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _dio.delete('/accounts/$id');

  Future<String> getBalance(String accountId) async {
    final response = await _dio.get('/accounts/$accountId/balance');
    return response.data['balance'] as String;
  }

  Future<List<AccountBalanceHistoryPoint>> getBalanceHistory(
    String accountId, {
    int months = 12,
  }) async {
    final response = await _dio.get(
      '/accounts/$accountId/balance-history',
      queryParameters: {'months': months},
    );
    return (response.data as List)
        .map(
          (json) =>
              AccountBalanceHistoryPoint.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }
}
