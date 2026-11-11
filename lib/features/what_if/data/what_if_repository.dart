import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import 'what_if.dart';

final whatIfRepositoryProvider = Provider<WhatIfRepository>((ref) {
  return WhatIfRepository(ref.watch(dioProvider));
});

class WhatIfRepository {
  WhatIfRepository(this._dio);

  final Dio _dio;

  /// Simulates a purchase made today; nothing is saved.
  Future<WhatIfResult> simulate(WhatIfRequest request) async {
    final response = await _dio.post(
      '/insights/what-if',
      data: request.toJson(),
    );
    return WhatIfResult.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<List<WishlistItem>> wishlist() async {
    final response = await _dio.get('/wishlist');
    return (response.data as List)
        .map((j) => WishlistItem.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  Future<void> addToWishlist({
    required String description,
    required String amount,
    double? pixDiscountPercent,
    int? interestFreeInstallments,
  }) async {
    await _dio.post(
      '/wishlist',
      data: {
        'description': description,
        'amount': amount,
        'pixDiscountPercent': ?pixDiscountPercent,
        'interestFreeInstallments': ?interestFreeInstallments,
      },
    );
  }

  Future<void> removeFromWishlist(String id) async {
    await _dio.delete('/wishlist/$id');
  }
}
