import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/offline/connectivity.dart';
import '../../offline/sync_service.dart';
import '../../purchases/data/purchases_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../totals/application/totals_providers.dart';
import '../../transactions/presentation/add_transaction_sheet.dart';
import '../application/day_detail_providers.dart';
import '../application/ledger_providers.dart';
import '../data/day_detail_item.dart';
import '../data/saldos_column_filter.dart';

class DayDetailScreen extends ConsumerStatefulWidget {
  const DayDetailScreen({
    super.key,
    required this.date,
    this.initialFilter = SaldosColumnFilter.todas,
  });

  final DateTime date;

  /// Tapping a specific type's cell on Saldos (instead of the "saldo"
  /// column) opens this screen already filtered to that type.
  final SaldosColumnFilter initialFilter;

  @override
  ConsumerState<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends ConsumerState<DayDetailScreen> {
  late DateTime _date = DateTime(
    widget.date.year,
    widget.date.month,
    widget.date.day,
  );
  late SaldosColumnFilter _filter = widget.initialFilter;

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(dayDetailProvider(_date));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              date: _date,
              onPreviousDay: () => setState(
                () => _date = _date.subtract(const Duration(days: 1)),
              ),
              onNextDay: () =>
                  setState(() => _date = _date.add(const Duration(days: 1))),
              onAdd: () =>
                  showAddTransactionEntryPoint(context, initialDate: _date),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _FilterDropdown(
                filter: _filter,
                onChanged: (value) => setState(() => _filter = value),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: itemsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Erro: $error')),
                data: (items) {
                  final filtered = _filter == SaldosColumnFilter.todas
                      ? items
                      : items.where((i) => i.type == _filter).toList();
                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('Nenhuma movimentação neste dia.'),
                    );
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _ItemTile(item: filtered[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.date,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onAdd,
  });

  final DateTime date;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPreviousDay,
          ),
          Text(
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNextDay,
          ),
          const Spacer(),
          IconButton(icon: const Icon(Icons.add), onPressed: onAdd),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.filter, required this.onChanged});

  final SaldosColumnFilter filter;
  final ValueChanged<SaldosColumnFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showFilterSheet(context),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.filter_list,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                filter.label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Mostrar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            for (final option in SaldosColumnFilter.values)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: option.color,
                  child: Icon(option.icon, color: Colors.white, size: 16),
                ),
                title: Text(option.label),
                trailing: option == filter ? const Icon(Icons.check) : null,
                onTap: () {
                  onChanged(option);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({required this.item});

  final DayDetailItem item;

  /// Card-purchase/installment rows aren't backed by a `Transaction` row —
  /// there's no edit flow for those, so they stay tap-to-edit-free.
  bool get _isEditable => item.installment == null;

  /// A plain lançamento is always deletable. A card-purchase row only is
  /// when it's one occurrence of a subscription (`item.recurring != null`)
  /// — deleting a one-off or a parcelamento installment isn't offered here.
  bool get _isDeletable => _isEditable || item.recurring != null;

  void _refreshAfterChange(WidgetRef ref) {
    final date = DateTime(item.date.year, item.date.month, item.date.day);
    ref.invalidate(dayDetailProvider(date));
    ref.invalidate(dailyBalanceProvider);
    ref.invalidate(monthlyTotalsProvider);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    // A recurring occurrence offers "só esta" vs. "esta e as futuras"
    // (like Google Calendar) instead of a plain yes/no confirm. Centered,
    // stacked buttons instead of AlertDialog's default row — three options
    // (one of them long) never fit a single row cleanly.
    final scope = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir lançamento?'),
        content: Text('Remover "${item.description}" permanentemente.'),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (item.recurring != null) ...[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop('this'),
                  child: const Text('Somente esta'),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop('future'),
                  child: const Text('Esta e as futuras'),
                ),
              ] else
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop('this'),
                  child: const Text('Excluir'),
                ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ],
      ),
    );
    if (scope == null) return;

    // "Esta e as futuras" can silently wipe out months (or years) of a
    // recurring series — ask once more before committing to it.
    if (scope == 'future') {
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Tem certeza?'),
          content: const Text(
            'Isso vai excluir esta ocorrência e todas as futuras desse lançamento recorrente. Não pode ser desfeito.',
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Sim, excluir todas'),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!context.mounted) return;
    final sync = ref.read(syncServiceProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      var savedOffline = false;
      if (item.installment != null) {
        await sync.requireOnline(
          () => ref
              .read(purchasesRepositoryProvider)
              .delete(item.id, scope: scope),
        );
      } else if (scope == 'future') {
        // The server knows the whole series; offline only "somente esta".
        await sync.requireOnline(
          () => ref
              .read(transactionsRepositoryProvider)
              .delete(item.id, scope: scope),
        );
      } else {
        savedOffline = await sync.deleteTransaction(item.id);
      }
      if (savedOffline) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(
              'Excluído no aparelho — será enviado quando a internet voltar.',
            ),
          ),
        );
      }
    } on OfflineException catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(e.message)));
    }
    _refreshAfterChange(ref);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    await showEditTransactionSheet(context, item.id);
    _refreshAfterChange(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: item.type.color,
            child: Icon(item.type.icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${item.date.day.toString().padLeft(2, '0')}/${item.date.month.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (item.isPending) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'aguardando envio',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.categoryName != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (item.categoryColor ??
                                  Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest)
                              .withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.categoryName!,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: item.categoryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(item.amount),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (item.installment != null) ...[
                const SizedBox(height: 2),
                Text(
                  '# ${item.installment!.sequence}/${item.installment!.count} mensais',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (!_isEditable && !_isDeletable) return content;
    return InkWell(
      onTap: _isEditable ? () => _edit(context, ref) : null,
      onLongPress: _isDeletable ? () => _confirmDelete(context, ref) : null,
      child: content,
    );
  }
}
