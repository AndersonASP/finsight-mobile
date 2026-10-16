import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
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
    return (response.data as List).map((json) => Scenario.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Scenario> create({required String name, String? description}) async {
    final response = await _dio.post('/scenarios', data: {'name': name, 'description': ?description});
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

  Future<void> discard(String scenarioId) => _dio.delete('/scenarios/$scenarioId');

  Future<void> confirm(String scenarioId) => _dio.post('/scenarios/$scenarioId/confirm');

  Future<ScenarioProjection> projection({required String scenarioId, required DateTime from, required DateTime to}) async {
    final response = await _dio.get(
      '/scenarios/$scenarioId/projection',
      queryParameters: {'from': _formatDate(from), 'to': _formatDate(to)},
    );
    return ScenarioProjection.fromJson(response.data as Map<String, dynamic>);
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
