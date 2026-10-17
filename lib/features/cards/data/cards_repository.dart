import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import 'fin_card.dart';

final cardsRepositoryProvider = Provider<CardsRepository>((ref) {
  return CardsRepository(ref.watch(dioProvider));
});

class CardsRepository {
  CardsRepository(this._dio);

  final Dio _dio;

  Future<List<FinCard>> list() async {
    final response = await _dio.get('/cards');
    return (response.data as List)
        .map((json) => FinCard.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<FinCard> create({
    required String name,
    String? brand,
    required int closingDay,
    required int dueDay,
    required String defaultPaymentAccountId,
  }) async {
    final response = await _dio.post(
      '/cards',
      data: {
        'name': name,
        'brand': ?brand,
        'closingDay': closingDay,
        'dueDay': dueDay,
        'defaultPaymentAccountId': defaultPaymentAccountId,
      },
    );
    return FinCard.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _dio.delete('/cards/$id');
}
