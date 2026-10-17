import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/offline/connectivity.dart';
import '../../../core/providers/selected_month_provider.dart';
import '../../../core/providers/today_navigation_provider.dart';
import '../../../core/widgets/today_button.dart';
import '../../offline/pending_changes.dart';
import '../../offline/sync_service.dart';
import '../../purchases/presentation/add_purchase_sheet.dart';
import '../../transactions/data/transaction_type.dart';
import '../../transactions/presentation/add_transaction_sheet.dart';
import '../application/ledger_providers.dart';
import '../data/saldos_column_filter.dart';
import 'day_detail_screen.dart';
import 'monthly_balance_table.dart';

/// Long-pressing a typed cell on the Saldos table already tells us both the
/// day and the lançamento type — so this skips the type-picker step and
/// opens the matching form directly (the purchase sheet for "cartão", since
/// that type isn't a plain [FinTransactionType]).
void _openAddTransactionFor(
  BuildContext context,
  SaldosColumnFilter type,
  DateTime date,
) {
  switch (type) {
    case SaldosColumnFilter.cartao:
      showAddPurchaseSheet(context, initialDate: date);
    case SaldosColumnFilter.entrada:
      showAddTransactionForm(
        context,
        type: FinTransactionType.entrada,
        initialDate: date,
      );
    case SaldosColumnFilter.saida:
      showAddTransactionForm(
        context,
        type: FinTransactionType.saida,
        initialDate: date,
      );
    case SaldosColumnFilter.diario:
      showAddTransactionForm(
        context,
        type: FinTransactionType.diario,
        initialDate: date,
      );
    case SaldosColumnFilter.economia:
      showAddTransactionForm(
        context,
        type: FinTransactionType.economia,
        initialDate: date,
      );
    case SaldosColumnFilter.todas:
      break; // _TypeValueRow's `type` is always a concrete type, never `todas`.
  }
}

class SaldosScreen extends ConsumerStatefulWidget {
  const SaldosScreen({super.key});

  @override
  ConsumerState<SaldosScreen> createState() => _SaldosScreenState();
}

class _SaldosScreenState extends ConsumerState<SaldosScreen> {
  int _scrollToTodaySignal = 0;

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedMonthProvider);
    final filter = ref.watch(saldosColumnFilterProvider);
    final daysAsync = ref.watch(dailyBalanceProvider);
    final now = DateTime.now();

    ref.listen<int>(goToTodaySignalProvider, (previous, next) {
      if (previous == next) return;
      final currentMonth = DateTime(now.year, now.month);
      if (month != currentMonth) {
        ref.read(selectedMonthProvider.notifier).state = currentMonth;
      }
      setState(() => _scrollToTodaySignal++);
    });

    ref.listen<List<String>>(syncRejectionsProvider, (previous, next) {
      if (next.isEmpty) return;
      final messenger = ScaffoldMessenger.of(context);
      for (final message in next) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
      ref.read(syncRejectionsProvider.notifier).state = const [];
    });

    return Scaffold(
      // bottom: false — the table scrolls behind the floating nav bar; its
      // list pads itself by the bar's height instead (see MonthlyBalanceTable).
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopHeader(month: month),
            const _OfflineBanner(),
            Expanded(
              child: MonthlyBalanceTable(
                daysAsync: daysAsync,
                filter: filter,
                scrollToTodaySignal: _scrollToTodaySignal,
                onFilterChanged: (value) =>
                    ref.read(saldosColumnFilterProvider.notifier).state = value,
                onCellTap: (type, date) => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        DayDetailScreen(date: date, initialFilter: type),
                  ),
                ),
                onCellLongPress: (type, date) =>
                    _openAddTransactionFor(context, type, date),
                onSaldoTap: (date) => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DayDetailScreen(date: date),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopHeader extends ConsumerWidget {
  const _TopHeader({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          const TodayButton(),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => ref.read(selectedMonthProvider.notifier).state =
                month.previousMonth,
          ),
          Text(
            formatMonth(month),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => ref.read(selectedMonthProvider.notifier).state =
                month.nextMonth,
          ),
          const Spacer(),
          const SizedBox(
            width: 34,
          ), // balances the TodayButton so the month stays centered
        ],
      ),
    );
  }
}

/// Shown while the API is unreachable or lançamentos are waiting to be
/// sent — so it's always clear the table may not be the server's latest.
/// Tapping it retries right away instead of waiting for the next attempt.
class _OfflineBanner extends ConsumerWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(connectivityProvider);
    final pendingCount = ref.watch(pendingChangesProvider).count;
    if (!isOffline && pendingCount == 0) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final pendingText = pendingCount == 0
        ? null
        : pendingCount == 1
        ? '1 alteração aguardando envio'
        : '$pendingCount alterações aguardando envio';
    final text = isOffline
        ? ['Sem conexão — dados salvos no aparelho', ?pendingText].join(' · ')
        : 'Sincronizando: $pendingText';

    return Material(
      color: colors.secondaryContainer,
      child: InkWell(
        onTap: () => ref.read(syncServiceProvider).flush(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(
                isOffline
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_sync_outlined,
                size: 16,
                color: colors.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
