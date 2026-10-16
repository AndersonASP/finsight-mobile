import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/reserve_loan.dart';
import '../data/reserve_loans_repository.dart';

final activeReserveLoansProvider = FutureProvider.autoDispose
    .family<List<ReserveLoan>, String>((ref, accountId) {
      return ref
          .watch(reserveLoansRepositoryProvider)
          .listForAccount(accountId, status: ReserveLoanStatus.active);
    });

final reserveLoanOwedProvider = FutureProvider.autoDispose
    .family<ReserveLoanOwed, String>((ref, loanId) {
      return ref.watch(reserveLoansRepositoryProvider).owed(loanId);
    });
