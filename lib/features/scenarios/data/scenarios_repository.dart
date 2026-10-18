import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import '../../reports/data/daily_balance_day.dart';
import '../../transactions/data/transaction_type.dart';
import 'scenario.dart';

final scenariosRepositoryProvider = Provider<ScenariosRepository>((ref) {
  return ScenariosRepository(ref.watch(dioProvider));
});

class ScenariosRepository {
  ScenariosRepository(this._dio);

  final Dio _dio;

  Future<List<Scenario>> list() async {
    final response = await _dio.get('/scenarios');
    return (response.data as List)
        .map((json) => Scenario.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Scenario> create({required String name, String? description}) async {
    final response = await _dio.post(
      '/scenarios',
      data: {'name': name, 'description': ?description},
    );
    return Scenario.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> detail(String scenarioId) async {
    final response = await _dio.get('/scenarios/$scenarioId');
    return response.data as Map<String, dynamic>;
  }

  Future<void> addTransaction({
    required String scenarioId,
    required String accountId,
    required FinTransactionType type,
    required String amount,
    required DateTime date,
    String? categoryId,
    String? description,
    String? counterpartAccountId,
  }) {
    return _dio.post(
      '/scenarios/$scenarioId/transactions',
      data: {
        'accountId': accountId,
        'type': type.apiValue,
        'amount': amount,
        'date': _formatDate(date),
        'categoryId': ?categoryId,
        'description': ?description,
        'counterpartAccountId': ?counterpartAccountId,
      },
    );
  }

  Future<void> addPurchase({
    required String scenarioId,
    required String cardId,
    required DateTime purchaseDate,
    required String description,
    required String amount,
    String? categoryId,
    int installmentsCount = 1,
  }) {
    return _dio.post(
      '/scenarios/$scenarioId/purchases',
      data: {
        'cardId': cardId,
        'purchaseDate': _formatDate(purchaseDate),
        'description': description,
        'amount': amount,
        'categoryId': ?categoryId,
        'installmentsCount': installmentsCount,
      },
    );
  }

  Future<void> removeTransaction(String scenarioId, String transactionId) =>
      _dio.delete('/scenarios/$scenarioId/transactions/$transactionId');

  Future<void> removePurchase(String scenarioId, String purchaseId) =>
      _dio.delete('/scenarios/$scenarioId/purchases/$purchaseId');

  Future<List<DailyBalanceDay>> dailyBalance({
    required String scenarioId,
    required int year,
    required int month,
  }) async {
    final response = await _dio.get(
      '/scenarios/$scenarioId/daily-balance',
      queryParameters: {'year': year, 'month': month},
    );
    return (response.data as List)
        .map((json) => DailyBalanceDay.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<ScenarioDayDetail> dayDetail(String scenarioId, DateTime date) async {
    final response = await _dio.get(
      '/scenarios/$scenarioId/day-detail',
      queryParameters: {'date': _formatDate(date)},
    );
    return ScenarioDayDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> discard(String scenarioId) =>
      _dio.delete('/scenarios/$scenarioId');

  /// Removes the simulação for good (any status), unlike [discard] which
  /// keeps a draft around marked "descartada".
  Future<void> delete(String scenarioId) => _dio.delete(
    '/scenarios/$scenarioId',
    queryParameters: {'permanent': 'true'},
  );

  Future<void> confirm(String scenarioId) =>
      _dio.post('/scenarios/$scenarioId/confirm');

  Future<ScenarioProjection> projection({
    required String scenarioId,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _dio.get(
      '/scenarios/$scenarioId/projection',
      queryParameters: {'from': _formatDate(from), 'to': _formatDate(to)},
    );
    return ScenarioProjection.fromJson(response.data as Map<String, dynamic>);
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
