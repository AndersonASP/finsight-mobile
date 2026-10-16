import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import 'reserve_loan.dart';

final reserveLoansRepositoryProvider = Provider<ReserveLoansRepository>((ref) {
  return ReserveLoansRepository(ref.watch(dioProvider));
});

class ReserveLoansRepository {
  ReserveLoansRepository(this._dio);

  final Dio _dio;

  Future<List<ReserveLoan>> listForAccount(
    String accountId, {
    ReserveLoanStatus? status,
  }) async {
    final response = await _dio.get(
      '/reserve-loans',
      queryParameters: {
        'accountId': accountId,
        if (status != null) 'status': status.name,
      },
    );
    return (response.data as List)
        .map((json) => ReserveLoan.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<ReserveLoan> borrow({
    required String reserveAccountId,
    required String destinationAccountId,
    required String principal,
    required DateTime borrowDate,
    String? description,
  }) async {
    final response = await _dio.post(
      '/reserve-loans',
      data: {
        'reserveAccountId': reserveAccountId,
        'destinationAccountId': destinationAccountId,
        'principal': principal,
        'borrowDate': _formatDate(borrowDate),
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
    return ReserveLoan.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ReserveLoanOwed> owed(String loanId) async {
    final response = await _dio.get('/reserve-loans/$loanId/owed');
    return ReserveLoanOwed.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ReserveLoanRepayment> repay(
    String loanId, {
    required String amount,
    required DateTime repaymentDate,
  }) async {
    final response = await _dio.post(
      '/reserve-loans/$loanId/repayments',
      data: {'amount': amount, 'repaymentDate': _formatDate(repaymentDate)},
    );
    return ReserveLoanRepayment.fromJson(response.data as Map<String, dynamic>);
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
