import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/widgets/brl_amount_field.dart';
import '../../../core/widgets/form_row.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../application/debts_providers.dart';
import '../data/debt.dart';
import '../data/debts_repository.dart';

class DebtDetailScreen extends ConsumerWidget {
  const DebtDetailScreen({super.key, required this.debtId});

  final String debtId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(debtDetailProvider(debtId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dívida'),
        actions: [
          detailAsync.maybeWhen(
            data: (detail) => IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref, detail.debt),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: detailAsync.maybeWhen(
        data: (detail) => detail.debt.status == DebtStatus.paga
            ? null
            : FloatingActionButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => _RegisterPaymentSheet(debtId: debtId),
                ),
                child: const Icon(Icons.add),
              ),
        orElse: () => null,
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (detail) {
          final debt = detail.debt;
          final isOverdue = debt.status == DebtStatus.vencida;
          final statusColor = isOverdue
              ? Theme.of(context).colorScheme.error
              : null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                debt.creditor,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                debt.type.label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (isOverdue) ...[
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: statusColor,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    debt.status.label,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'saldo devedor',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(
                formatCurrency(debt.currentBalance),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (debt.installmentsTotal != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${debt.installmentsPaid}/${debt.installmentsTotal} parcelas'
                  '${debt.installmentAmount != null ? ' de ${formatCurrency(debt.installmentAmount!)}' : ''}',
                ),
              ],
              const Divider(height: 32),
              Text(
                'Pagamentos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (detail.payments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Nenhum pagamento registrado ainda.'),
                ),
              for (final payment in detail.payments.reversed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(formatCurrency(payment.amount)),
                  subtitle: Text(
                    '${payment.paymentDate.day.toString().padLeft(2, '0')}/${payment.paymentDate.month.toString().padLeft(2, '0')}/${payment.paymentDate.year}'
                    ' · saldo restante ${formatCurrency(payment.balanceAfter)}',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Debt debt) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir dívida?'),
        content: Text(
          'Remover "${debt.creditor}" e todo o histórico de pagamentos permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(debtsRepositoryProvider).delete(debt.id);
              ref.invalidate(debtsListProvider);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

class _RegisterPaymentSheet extends ConsumerStatefulWidget {
  const _RegisterPaymentSheet({required this.debtId});

  final String debtId;

  @override
  ConsumerState<_RegisterPaymentSheet> createState() =>
      _RegisterPaymentSheetState();
}

class _RegisterPaymentSheetState extends ConsumerState<_RegisterPaymentSheet> {
  final _amountController = TextEditingController();
  String? _accountId;
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = BrlAmountField.toApiAmount(_amountController.text);
    if (amount == null || _accountId == null) {
      setState(() => _error = 'Informe o valor e a conta de origem.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(debtsRepositoryProvider)
          .createPayment(
            widget.debtId,
            accountId: _accountId!,
            amount: amount,
            paymentDate: _date,
          );
      ref.invalidate(debtDetailProvider(widget.debtId));
      ref.invalidate(debtsListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Não foi possível registrar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsListProvider);

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
            'Registrar pagamento',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          BrlAmountFormField(
            controller: _amountController,
            labelText: 'Valor pago',
            autofocus: true,
          ),
          const SizedBox(height: 12),
          accountsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Erro ao carregar contas: $e'),
            data: (accounts) {
              if (accounts.isEmpty) {
                return OutlinedButton.icon(
                  onPressed: () async {
                    final created = await showCreateAccountSheet(context);
                    if (created != null)
                      setState(() => _accountId = created.id);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('criar conta'),
                );
              }
              return DropdownButtonFormField<String>(
                initialValue: accounts.any((a) => a.id == _accountId)
                    ? _accountId
                    : null,
                decoration: const InputDecoration(labelText: 'Conta de origem'),
                items: accounts
                    .map(
                      (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _accountId = value),
              );
            },
          ),
          const SizedBox(height: 12),
          FormRow(
            leading: const Icon(Icons.calendar_today_outlined),
            title: 'data',
            trailingText:
                '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
            onTap: _pickDate,
          ),
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
                : const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
