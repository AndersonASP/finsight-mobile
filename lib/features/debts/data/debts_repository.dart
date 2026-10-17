import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import 'debt.dart';

final debtsRepositoryProvider = Provider<DebtsRepository>((ref) {
  return DebtsRepository(ref.watch(dioProvider));
});

/// Debts are only described here (what's left is derived by the API, see
/// GET /wealth) — payments are never registered.
class DebtsRepository {
  DebtsRepository(this._dio);

  final Dio _dio;

  Future<List<Debt>> list() async {
    final response = await _dio.get('/debts');
    return (response.data as List)
        .map((json) => Debt.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Debt> get(String id) async {
    final response = await _dio.get('/debts/$id');
    final data = response.data as Map<String, dynamic>;
    return Debt.fromJson(data['debt'] as Map<String, dynamic>);
  }

  /// Fixed installments: [installmentAmount], [installmentsTotal],
  /// [installmentDueDay] and [currentInstallment] ("estou na parcela X" — the
  /// one due this month). Variable balance: [currentBalance].
  Future<Debt> save({
    String? id,
    required String creditor,
    required DebtType type,
    required DebtKind kind,
    String? currentBalance,
    String? installmentAmount,
    int? installmentsTotal,
    int? installmentDueDay,
    int? currentInstallment,
    String? payoffAmount,
    bool clearPayoff = false,
    String? monthlyInterestRate,
    bool clearInterestRate = false,
    DebtStatus? status,
  }) async {
    final data = {
      'creditor': creditor,
      'type': type.apiValue,
      'kind': kind == DebtKind.parcelaFixa ? 'parcela_fixa' : 'saldo_variavel',
      'currentBalance': ?currentBalance,
      'installmentAmount': ?installmentAmount,
      'installmentsTotal': ?installmentsTotal,
      'installmentDueDay': ?installmentDueDay,
      'currentInstallment': ?currentInstallment,
      if (clearPayoff) 'payoffAmount': null else 'payoffAmount': ?payoffAmount,
      if (clearInterestRate)
        'monthlyInterestRate': null
      else
        'monthlyInterestRate': ?monthlyInterestRate,
      'status': ?status?.apiValue,
    };
    final response = id == null
        ? await _dio.post('/debts', data: data)
        : await _dio.patch('/debts/$id', data: data);
    return Debt.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _dio.delete('/debts/$id');
}
