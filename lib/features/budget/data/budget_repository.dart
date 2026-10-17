import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import 'budget_item.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(dioProvider));
});

class BudgetRepository {
  BudgetRepository(this._dio);

  final Dio _dio;

  Future<List<BudgetItem>> list() async {
    final response = await _dio.get('/budget-items');
    return (response.data as List)
        .map((json) => BudgetItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<BudgetItem> create({
    required String name,
    required String amount,
  }) async {
    final response = await _dio.post(
      '/budget-items',
      data: {'name': name, 'amount': amount},
    );
    return BudgetItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _dio.delete('/budget-items/$id');

  Future<BudgetSummary> summary({required int year, required int month}) async {
    final response = await _dio.get(
      '/budget-items/summary',
      queryParameters: {'year': year, 'month': month},
    );
    return BudgetSummary.fromJson(response.data as Map<String, dynamic>);
  }
}
