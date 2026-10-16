import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import 'account.dart';
import 'account_balance_history_point.dart';

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return AccountsRepository(ref.watch(dioProvider));
});

class AccountsRepository {
  AccountsRepository(this._dio);

  final Dio _dio;

  Future<List<Account>> list() async {
    final response = await _dio.get('/accounts');
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
