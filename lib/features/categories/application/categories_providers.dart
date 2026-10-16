import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/categories_repository.dart';
import '../data/category.dart';

final categoriesListProvider = FutureProvider.autoDispose<List<Category>>((ref) {
  return ref.watch(categoriesRepositoryProvider).list();
});
