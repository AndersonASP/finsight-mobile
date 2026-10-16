import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';

final invoicePaymentsRepositoryProvider = Provider<InvoicePaymentsRepository>((ref) {
  return InvoicePaymentsRepository(ref.watch(dioProvider));
});

class InvoicePaymentsRepository {
  InvoicePaymentsRepository(this._dio);

  final Dio _dio;

  Future<void> create({
    required String invoiceId,
    required String accountId,
    required DateTime paymentDate,
    required String amount,
    String? interestAmount,
  }) {
    return _dio.post(
      '/invoices/$invoiceId/payments',
      data: {
        'accountId': accountId,
        'paymentDate': _formatDate(paymentDate),
        'amount': amount,
        'interestAmount': ?interestAmount,
      },
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
