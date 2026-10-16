import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/debt.dart';
import '../data/debts_repository.dart';

final debtsListProvider = FutureProvider.autoDispose<List<Debt>>((ref) {
  return ref.watch(debtsRepositoryProvider).list();
});

final debtDetailProvider = FutureProvider.autoDispose
    .family<DebtDetail, String>((ref, debtId) {
      return ref.watch(debtsRepositoryProvider).getDetail(debtId);
    });
