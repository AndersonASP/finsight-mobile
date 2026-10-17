import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/native/native_bridge.dart';
import '../../../core/offline/connectivity.dart';
import '../../purchases/presentation/add_purchase_sheet.dart';
import '../../transactions/data/transaction_type.dart';
import '../../transactions/presentation/add_transaction_sheet.dart';
import '../data/wallet_card_mapping.dart';

final walletMappingsProvider =
    FutureProvider.autoDispose<List<WalletCardMapping>>((ref) {
      ref.watch(connectivityProvider);
      final repository = ref.watch(walletMappingsRepositoryProvider);
      return networkOrCache(
        ref,
        network: repository.list,
        cache: repository.cachedList,
      );
    });

/// Opens the pre-filled form for a purchase an Apple Pay automation handed
/// over to the app (it couldn't log it alone). Débito-linked Wallet cards
/// open a "diário" lançamento on that account; anything else, a card purchase.
Future<void> openPendingQuickEntry(BuildContext context, WidgetRef ref) async {
  final entry = await NativeBridge.takePendingQuickEntry();
  if (entry == null || !context.mounted) return;

  WalletCardMapping? mapping;
  if (entry.cardName != null) {
    final wallet = normalizeWalletName(entry.cardName!);
    List<WalletCardMapping>? mappings;
    try {
      mappings = await ref.read(walletMappingsProvider.future);
    } catch (_) {
      mappings = ref.read(walletMappingsRepositoryProvider).cachedList();
    }
    for (final m in mappings ?? const <WalletCardMapping>[]) {
      if (m.walletName == wallet) mapping = m;
    }
  }
  if (!context.mounted) return;

  if (mapping?.accountId != null) {
    await showAddTransactionForm(
      context,
      type: FinTransactionType.diario,
      initialDate: entry.date,
      initialAmount: entry.amount,
      initialDescription: entry.merchant,
      initialAccountId: mapping!.accountId,
    );
    return;
  }
  await showAddPurchaseSheet(
    context,
    initialDate: entry.date,
    initialAmount: entry.amount,
    initialDescription: entry.merchant,
    initialCardId: mapping?.cardId,
    initialCardName: entry.cardName,
  );
}
