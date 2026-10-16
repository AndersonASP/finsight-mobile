import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/widgets/brl_amount_field.dart';
import '../../ledger/application/ledger_providers.dart';
import '../../totals/application/totals_providers.dart';
import '../application/budget_providers.dart';
import '../data/budget_item.dart';
import '../data/budget_repository.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(budgetItemsListProvider);
    final summaryAsync = ref.watch(budgetSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('previsão de diário'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Erro: $error')),
              data: (items) {
                if (items.isEmpty)
                  return const Center(
                    child: Text('Nenhum item de previsão ainda.'),
                  );
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _BudgetTile(item: items[index]),
                );
              },
            ),
          ),
          const Divider(height: 1),
          summaryAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Erro: $error'),
            ),
            data: (summary) => _SummaryFooter(summary: summary),
          ),
        ],
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateBudgetItemSheet(),
    );
  }
}

class _BudgetTile extends ConsumerWidget {
  const _BudgetTile({required this.item});

  final BudgetItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(item.name),
      trailing: Text(formatCurrency(item.amount)),
      onLongPress: () async {
        await ref.read(budgetRepositoryProvider).delete(item.id);
        ref.invalidate(budgetItemsListProvider);
        ref.invalidate(budgetSummaryProvider);
        ref.invalidate(dailyBalanceProvider);
        ref.invalidate(monthlyTotalsProvider);
      },
    );
  }
}

class _SummaryFooter extends StatelessWidget {
  const _SummaryFooter({required this.summary});

  final BudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('total mensal'),
              Text(formatCurrency(summary.total)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('dividido por'),
              Text('${summary.days} dias'),
            ],
          ),
          const Divider(),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              formatCurrency(summary.dailyAverage),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateBudgetItemSheet extends ConsumerStatefulWidget {
  const _CreateBudgetItemSheet();

  @override
  ConsumerState<_CreateBudgetItemSheet> createState() =>
      _CreateBudgetItemSheetState();
}

class _CreateBudgetItemSheetState
    extends ConsumerState<_CreateBudgetItemSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = BrlAmountField.toApiAmount(_amountController.text);
    if (_nameController.text.trim().isEmpty || amount == null) return;
    setState(() => _saving = true);
    await ref
        .read(budgetRepositoryProvider)
        .create(name: _nameController.text.trim(), amount: amount);
    ref.invalidate(budgetItemsListProvider);
    ref.invalidate(budgetSummaryProvider);
    ref.invalidate(dailyBalanceProvider);
    ref.invalidate(monthlyTotalsProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Novo item de previsão',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nome (ex: Barbeiro)'),
          ),
          const SizedBox(height: 12),
          BrlAmountFormField(
            controller: _amountController,
            labelText: 'Valor mensal',
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
