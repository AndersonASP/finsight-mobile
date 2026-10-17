import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/invoice.dart';
import '../data/invoices_repository.dart';

final cardInvoicesProvider = FutureProvider.autoDispose
    .family<List<Invoice>, String>((ref, cardId) {
      return ref.watch(invoicesRepositoryProvider).list(cardId: cardId);
    });

final invoiceDetailProvider = FutureProvider.autoDispose
    .family<InvoiceDetail, String>((ref, invoiceId) {
      return ref.watch(invoicesRepositoryProvider).detail(invoiceId);
    });
