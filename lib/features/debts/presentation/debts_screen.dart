import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/widgets/brl_amount_field.dart';
import '../application/debts_providers.dart';
import '../data/debt.dart';
import '../data/debts_repository.dart';
import 'debt_detail_screen.dart';

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dívidas')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _CreateDebtSheet(),
        ),
        child: const Icon(Icons.add),
      ),
      body: debtsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (debts) {
          if (debts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhuma dívida cadastrada ainda.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: debts.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _DebtTile(debt: debts[index]),
          );
        },
      ),
    );
  }
}

class _DebtTile extends StatelessWidget {
  const _DebtTile({required this.debt});

  final Debt debt;

  @override
  Widget build(BuildContext context) {
    final isOverdue = debt.status == DebtStatus.vencida;
    final statusColor = isOverdue ? Theme.of(context).colorScheme.error : null;

    return ListTile(
      title: Text(debt.creditor),
      subtitle: Row(
        children: [
          if (isOverdue) ...[
            Icon(Icons.warning_amber_rounded, size: 14, color: statusColor),
            const SizedBox(width: 4),
          ],
          Text(
            '${debt.type.label} · ${debt.status.label}',
            style: TextStyle(color: statusColor),
          ),
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatCurrency(debt.currentBalance),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (debt.installmentsTotal != null)
            Text(
              '${debt.installmentsPaid}/${debt.installmentsTotal} parcelas',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DebtDetailScreen(debtId: debt.id)),
      ),
    );
  }
}

class _CreateDebtSheet extends ConsumerStatefulWidget {
  const _CreateDebtSheet();

  @override
  ConsumerState<_CreateDebtSheet> createState() => _CreateDebtSheetState();
}

class _CreateDebtSheetState extends ConsumerState<_CreateDebtSheet> {
  final _creditorController = TextEditingController();
  final _balanceController = TextEditingController();
  final _installmentAmountController = TextEditingController();
  final _installmentDueDayController = TextEditingController();
  final _installmentsTotalController = TextEditingController();
  DebtType _type = DebtType.consignado;
  DebtStatus _status = DebtStatus.emDia;
  bool _saving = false;
  String? _error;

  bool get _hasInstallments =>
      _type == DebtType.consignado || _type == DebtType.emprestimoPessoal;

  @override
  void dispose() {
    _creditorController.dispose();
    _balanceController.dispose();
    _installmentAmountController.dispose();
    _installmentDueDayController.dispose();
    _installmentsTotalController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final balance = BrlAmountField.toApiAmount(_balanceController.text);
    if (_creditorController.text.trim().isEmpty || balance == null) {
      setState(() => _error = 'Preencha credor e saldo devedor.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(debtsRepositoryProvider)
          .create(
            creditor: _creditorController.text.trim(),
            type: _type,
            status: _status,
            currentBalance: balance,
            installmentAmount: _hasInstallments
                ? BrlAmountField.toApiAmount(_installmentAmountController.text)
                : null,
            installmentDueDay: _hasInstallments
                ? int.tryParse(_installmentDueDayController.text)
                : null,
            installmentsTotal: _hasInstallments
                ? int.tryParse(_installmentsTotalController.text)
                : null,
          );
      ref.invalidate(debtsListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Não foi possível salvar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nova dívida', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _creditorController,
              decoration: const InputDecoration(
                labelText: 'Credor (ex: Banco X)',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DebtType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: DebtType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DebtStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: DebtStatus.values
                  .where((s) => s != DebtStatus.paga)
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (value) => setState(() => _status = value ?? _status),
            ),
            const SizedBox(height: 12),
            BrlAmountFormField(
              controller: _balanceController,
              labelText: 'Saldo devedor atual',
            ),
            if (_hasInstallments) ...[
              const SizedBox(height: 12),
              BrlAmountFormField(
                controller: _installmentAmountController,
                labelText: 'Valor da parcela',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _installmentDueDayController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Dia do vencimento',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _installmentsTotalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total de parcelas',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
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
      ),
    );
  }
}
