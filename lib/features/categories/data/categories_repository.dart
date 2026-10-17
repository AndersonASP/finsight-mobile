import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/offline/offline_store.dart';
import 'category.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(
    ref.watch(dioProvider),
    ref.watch(offlineStoreProvider),
  );
});

class CategoriesRepository {
  CategoriesRepository(this._dio, this._store);

  final Dio _dio;
  final OfflineStore _store;

  static const _cacheKey = 'categories';

  List<Category>? cachedList() {
    final data = _store.read(_cacheKey);
    if (data is! List) return null;
    return data
        .map(
          (json) => Category.fromJson(Map<String, dynamic>.from(json as Map)),
        )
        .toList();
  }

  Future<List<Category>> list() async {
    final response = await _dio.get('/categories');
    _store.write(_cacheKey, response.data);
    return (response.data as List)
        .map((json) => Category.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Category> create({required String name, required Color color}) async {
    final hex = '#${color.toARGB32().toRadixString(16).substring(2)}';
    final response = await _dio.post(
      '/categories',
      data: {'name': name, 'color': hex},
    );
    return Category.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Category> update({
    required String id,
    String? name,
    Color? color,
  }) async {
    final hex = color == null
        ? null
        : '#${color.toARGB32().toRadixString(16).substring(2)}';
    final response = await _dio.patch(
      '/categories/$id',
      data: {'name': ?name, 'color': ?hex},
    );
    return Category.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _dio.delete('/categories/$id');

  Future<String> getTotal(
    String categoryId, {
    required int year,
    required int month,
  }) async {
    final response = await _dio.get(
      '/categories/$categoryId/totals',
      queryParameters: {'year': year, 'month': month},
    );
    return response.data['total'] as String;
  }
}
