import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/offline/connectivity.dart';
import '../data/categories_repository.dart';
import '../data/category.dart';

final categoriesListProvider = FutureProvider.autoDispose<List<Category>>((
  ref,
) {
  ref.watch(connectivityProvider);
  final repository = ref.watch(categoriesRepositoryProvider);
  return networkOrCache(
    ref,
    network: repository.list,
    cache: repository.cachedList,
  );
});
