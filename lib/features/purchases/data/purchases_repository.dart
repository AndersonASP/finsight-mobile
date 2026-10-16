import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  return PurchasesRepository(ref.watch(dioProvider));
});

class PurchasesRepository {
  PurchasesRepository(this._dio);

  final Dio _dio;

  Future<void> create({
    required String cardId,
    required DateTime purchaseDate,
    required String description,
    required String amount,
    String? categoryId,
    int installmentsCount = 1,
  }) {
    return _dio.post(
      '/purchases',
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

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
