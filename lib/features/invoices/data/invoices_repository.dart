import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import 'invoice.dart';

final invoicesRepositoryProvider = Provider<InvoicesRepository>((ref) {
  return InvoicesRepository(ref.watch(dioProvider));
});

class InvoicesRepository {
  InvoicesRepository(this._dio);

  final Dio _dio;

  Future<List<Invoice>> list({String? cardId}) async {
    final response = await _dio.get('/invoices', queryParameters: {'cardId': ?cardId});
    return (response.data as List).map((json) => Invoice.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<InvoiceDetail> detail(String invoiceId) async {
    final response = await _dio.get('/invoices/$invoiceId');
    return InvoiceDetail.fromJson(response.data as Map<String, dynamic>);
  }
}
