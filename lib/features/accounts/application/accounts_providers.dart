import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/account.dart';
import '../data/account_balance_history_point.dart';
import '../data/accounts_repository.dart';

final accountsListProvider = FutureProvider.autoDispose<List<Account>>((ref) {
  return ref.watch(accountsRepositoryProvider).list();
});

final accountBalanceHistoryProvider = FutureProvider.autoDispose
    .family<List<AccountBalanceHistoryPoint>, String>((ref, accountId) {
      return ref.watch(accountsRepositoryProvider).getBalanceHistory(accountId);
    });
