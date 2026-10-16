import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import 'category.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(ref.watch(dioProvider));
});

class CategoriesRepository {
  CategoriesRepository(this._dio);

  final Dio _dio;

  Future<List<Category>> list() async {
    final response = await _dio.get('/categories');
    return (response.data as List).map((json) => Category.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Category> create({required String name, required Color color}) async {
    final hex = '#${color.toARGB32().toRadixString(16).substring(2)}';
    final response = await _dio.post('/categories', data: {'name': name, 'color': hex});
    return Category.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _dio.delete('/categories/$id');

  Future<String> getTotal(String categoryId, {required int year, required int month}) async {
    final response = await _dio.get('/categories/$categoryId/totals', queryParameters: {'year': year, 'month': month});
    return response.data['total'] as String;
  }
}
