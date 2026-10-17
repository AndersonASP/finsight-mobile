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

  /// `scope: 'future'` only matters when [id] is one occurrence of a
  /// `RecurringCardPurchase` (a subscription) — removes that one and every
  /// later occurrence in the same series, keeping past ones. For any other
  /// purchase it just deletes that one purchase (every installment cascades).
  Future<void> delete(String id, {String scope = 'this'}) =>
      _dio.delete('/purchases/$id', queryParameters: {'scope': scope});

  /// Creates a subscription that charges the card the same amount every
  /// month (e.g. Netflix): [occurrenceCount] single (non-installment)
  /// purchases, or — when [isOpenEnded] is true — a long bounded window
  /// (the server picks how many months cover ~10 years, same reasoning as
  /// TransactionsRepository.createRecurring).
  Future<void> createRecurring({
    required String cardId,
    required String description,
    required String amount,
    required DateTime startDate,
    int? occurrenceCount,
    bool isOpenEnded = false,
    String? categoryId,
  }) {
    return _dio.post(
      '/recurring-card-purchases',
      data: {
        'cardId': cardId,
        'description': description,
        'amount': amount,
        'startDate': _formatDate(startDate),
        'occurrenceCount': ?occurrenceCount,
        'isOpenEnded': isOpenEnded,
        'categoryId': ?categoryId,
      },
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
