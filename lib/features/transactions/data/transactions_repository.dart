import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import 'fin_transaction.dart';
import 'recurrence_interval.dart';
import 'transaction_type.dart';

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  return TransactionsRepository(ref.watch(dioProvider));
});

class TransactionsRepository {
  TransactionsRepository(this._dio);

  final Dio _dio;

  Future<List<FinTransaction>> list({DateTime? from, DateTime? to}) async {
    final response = await _dio.get(
      '/transactions',
      queryParameters: {
        if (from != null) 'from': _formatDate(from),
        if (to != null) 'to': _formatDate(to),
      },
    );
    return (response.data as List)
        .map((json) => FinTransaction.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<FinTransaction> get(String id) async {
    final response = await _dio.get('/transactions/$id');
    return FinTransaction.fromJson(response.data as Map<String, dynamic>);
  }

  Future<FinTransaction> create({
    required String accountId,
    required FinTransactionType type,
    required String amount,
    required DateTime date,
    String? categoryId,
    String? description,
    String? counterpartAccountId,
  }) async {
    final response = await _dio.post(
      '/transactions',
      data: {
        'accountId': accountId,
        'type': type.apiValue,
        'amount': amount,
        'date': _formatDate(date),
        'categoryId': ?categoryId,
        if (description != null && description.isNotEmpty)
          'description': description,
        'counterpartAccountId': ?counterpartAccountId,
      },
    );
    return FinTransaction.fromJson(response.data as Map<String, dynamic>);
  }

  Future<FinTransaction> update(
    String id, {
    String? accountId,
    FinTransactionType? type,
    String? amount,
    DateTime? date,
    String? categoryId,
    String? description,
    String? counterpartAccountId,
  }) async {
    final response = await _dio.patch(
      '/transactions/$id',
      data: {
        'accountId': ?accountId,
        'type': ?type?.apiValue,
        'amount': ?amount,
        'date': ?date != null ? _formatDate(date) : null,
        'categoryId': ?categoryId,
        'description': ?description,
        'counterpartAccountId': ?counterpartAccountId,
      },
    );
    return FinTransaction.fromJson(response.data as Map<String, dynamic>);
  }

  /// `scope: 'future'` only matters when [id] is one occurrence of a
  /// recurring lançamento — removes that one and every later occurrence in
  /// the same series, keeping past ones. Ignored for a plain transaction.
  Future<void> delete(String id, {String scope = 'this'}) =>
      _dio.delete('/transactions/$id', queryParameters: {'scope': scope});

  /// Creates a recurring lançamento: [occurrenceCount] occurrences spaced by
  /// [interval], or — when [isOpenEnded] is true — a long bounded window
  /// (the server picks how many occurrences cover ~10 years for that
  /// interval, since there's no background job to extend an open series).
  Future<void> createRecurring({
    required String accountId,
    required FinTransactionType type,
    required String amount,
    required DateTime startDate,
    required RecurrenceInterval interval,
    int? occurrenceCount,
    bool isOpenEnded = false,
    String? categoryId,
    String? description,
    String? counterpartAccountId,
  }) {
    return _dio.post(
      '/recurring-transactions',
      data: {
        'accountId': accountId,
        'type': type.apiValue,
        'amount': amount,
        'startDate': _formatDate(startDate),
        'interval': interval.apiValue,
        'occurrenceCount': ?occurrenceCount,
        'isOpenEnded': isOpenEnded,
        'categoryId': ?categoryId,
        if (description != null && description.isNotEmpty)
          'description': description,
        'counterpartAccountId': ?counterpartAccountId,
      },
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
