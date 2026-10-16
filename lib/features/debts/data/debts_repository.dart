import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import 'debt.dart';

final debtsRepositoryProvider = Provider<DebtsRepository>((ref) {
  return DebtsRepository(ref.watch(dioProvider));
});

class DebtsRepository {
  DebtsRepository(this._dio);

  final Dio _dio;

  Future<List<Debt>> list({DebtStatus? status}) async {
    final response = await _dio.get(
      '/debts',
      queryParameters: {'status': ?status?.apiValue},
    );
    return (response.data as List)
        .map((json) => Debt.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<DebtDetail> getDetail(String id) async {
    final response = await _dio.get('/debts/$id');
    return DebtDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Debt> create({
    required String creditor,
    required DebtType type,
    DebtStatus? status,
    String? originalAmount,
    required String currentBalance,
    String? installmentAmount,
    int? installmentDueDay,
    int? installmentsTotal,
    String? notes,
  }) async {
    final response = await _dio.post(
      '/debts',
      data: {
        'creditor': creditor,
        'type': type.apiValue,
        'status': ?status?.apiValue,
        'originalAmount': ?originalAmount,
        'currentBalance': currentBalance,
        'installmentAmount': ?installmentAmount,
        'installmentDueDay': ?installmentDueDay,
        'installmentsTotal': ?installmentsTotal,
        'notes': ?notes,
      },
    );
    return Debt.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Debt> update(
    String id, {
    String? creditor,
    DebtType? type,
    DebtStatus? status,
    String? originalAmount,
    String? currentBalance,
    String? installmentAmount,
    int? installmentDueDay,
    int? installmentsTotal,
    String? notes,
  }) async {
    final response = await _dio.patch(
      '/debts/$id',
      data: {
        'creditor': ?creditor,
        'type': ?type?.apiValue,
        'status': ?status?.apiValue,
        'originalAmount': ?originalAmount,
        'currentBalance': ?currentBalance,
        'installmentAmount': ?installmentAmount,
        'installmentDueDay': ?installmentDueDay,
        'installmentsTotal': ?installmentsTotal,
        'notes': ?notes,
      },
    );
    return Debt.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _dio.delete('/debts/$id');

  Future<DebtPayment> createPayment(
    String debtId, {
    required String accountId,
    required String amount,
    required DateTime paymentDate,
    String? notes,
  }) async {
    final response = await _dio.post(
      '/debts/$debtId/payments',
      data: {
        'accountId': accountId,
        'amount': amount,
        'paymentDate': _formatDate(paymentDate),
        'notes': ?notes,
      },
    );
    return DebtPayment.fromJson(response.data as Map<String, dynamic>);
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
