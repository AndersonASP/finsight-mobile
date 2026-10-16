import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/widgets/brl_amount_field.dart';
import '../../../core/widgets/form_row.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../accounts/data/account.dart';
import '../../ledger/application/ledger_providers.dart';
import '../../totals/application/totals_providers.dart';
import '../application/reserve_loans_providers.dart';
import '../data/reserve_loan.dart';
import '../data/reserve_loans_repository.dart';

/// Opens the "empréstimo da reserva" sheet for a `savings_reserve` account:
/// borrow money out of it into another account, or pay back an open loan.
/// Kept as its own action (not folded into the normal "economia" transfer)
/// because a loan accrues interest and a plain savings transfer doesn't.
Future<void> showReserveLoanSheet(
  BuildContext context, {
  required Account reserveAccount,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ReserveLoanSheet(reserveAccount: reserveAccount),
  );
}

enum _LoanSheetMode { borrow, repay }

class _ReserveLoanSheet extends ConsumerStatefulWidget {
  const _ReserveLoanSheet({required this.reserveAccount});

  final Account reserveAccount;

  @override
  ConsumerState<_ReserveLoanSheet> createState() => _ReserveLoanSheetState();
}

class _ReserveLoanSheetState extends ConsumerState<_ReserveLoanSheet> {
  _LoanSheetMode _mode = _LoanSheetMode.borrow;

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
            Text(
              widget.reserveAccount.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SegmentedButton<_LoanSheetMode>(
              segments: const [
                ButtonSegment(
                  value: _LoanSheetMode.borrow,
                  label: Text('Pegar empréstimo'),
                ),
                ButtonSegment(
                  value: _LoanSheetMode.repay,
                  label: Text('Pagar empréstimo'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) =>
                  setState(() => _mode = selection.first),
            ),
            const SizedBox(height: 16),
            if (_mode == _LoanSheetMode.borrow)
              _BorrowForm(reserveAccount: widget.reserveAccount)
            else
              _RepaySection(reserveAccount: widget.reserveAccount),
          ],
        ),
      ),
    );
  }
}

class _BorrowForm extends ConsumerStatefulWidget {
  const _BorrowForm({required this.reserveAccount});

  final Account reserveAccount;

  @override
  ConsumerState<_BorrowForm> createState() => _BorrowFormState();
}

class _BorrowFormState extends ConsumerState<_BorrowForm> {
  final _amountController = TextEditingController();
  String? _destinationAccountId;
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

  Future<void> _borrow() async {
    final amount = BrlAmountField.toApiAmount(_amountController.text);
    if (amount == null || _destinationAccountId == null) {
      setState(() => _error = 'Informe o valor e a conta de destino.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(reserveLoansRepositoryProvider)
          .borrow(
            reserveAccountId: widget.reserveAccount.id,
            destinationAccountId: _destinationAccountId!,
            principal: amount,
            borrowDate: _date,
          );
      ref.invalidate(accountsListProvider);
      ref.invalidate(activeReserveLoansProvider(widget.reserveAccount.id));
      ref.invalidate(dailyBalanceProvider);
      ref.invalidate(monthlyTotalsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Não foi possível pegar o empréstimo: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsListProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BrlAmountField(controller: _amountController, autofocus: true),
        const Divider(height: 24),
        accountsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Erro ao carregar contas: $e'),
          data: (accounts) {
            final destinations = accounts
                .where((a) => a.id != widget.reserveAccount.id)
                .toList();
            return DropdownButtonFormField<String>(
              initialValue:
                  destinations.any((a) => a.id == _destinationAccountId)
                  ? _destinationAccountId
                  : null,
              decoration: const InputDecoration(labelText: 'Conta de destino'),
              items: destinations
                  .map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _destinationAccountId = value),
            );
          },
        ),
        const Divider(height: 1),
        FormRow(
          leading: const Icon(Icons.calendar_today_outlined),
          title: 'data',
          trailingText:
              '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
          onTap: _pickDate,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Juro de 10% ao mês sobre o valor retirado, cobrado enquanto o empréstimo não for pago.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _borrow,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirmar empréstimo'),
        ),
      ],
    );
  }
}

class _RepaySection extends ConsumerWidget {
  const _RepaySection({required this.reserveAccount});

  final Account reserveAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(activeReserveLoansProvider(reserveAccount.id));

    return loansAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Text('Erro: $e'),
      data: (loans) {
        if (loans.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nenhum empréstimo em aberto desta reserva.'),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (final loan in loans) _LoanTile(loan: loan)],
        );
      },
    );
  }
}

class _LoanTile extends ConsumerStatefulWidget {
  const _LoanTile({required this.loan});

  final ReserveLoan loan;

  @override
  ConsumerState<_LoanTile> createState() => _LoanTileState();
}

class _LoanTileState extends ConsumerState<_LoanTile> {
  final _amountController = TextEditingController();
  bool _paying = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _repay() async {
    final amount = BrlAmountField.toApiAmount(_amountController.text);
    if (amount == null) {
      setState(() => _error = 'Informe o valor.');
      return;
    }
    setState(() {
      _paying = true;
      _error = null;
    });
    try {
      await ref
          .read(reserveLoansRepositoryProvider)
          .repay(widget.loan.id, amount: amount, repaymentDate: DateTime.now());
      ref.invalidate(accountsListProvider);
      ref.invalidate(activeReserveLoansProvider(widget.loan.reserveAccountId));
      ref.invalidate(reserveLoanOwedProvider(widget.loan.id));
      ref.invalidate(dailyBalanceProvider);
      ref.invalidate(monthlyTotalsProvider);
      _amountController.clear();
    } catch (e) {
      setState(() => _error = 'Não foi possível pagar: $e');
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owedAsync = ref.watch(reserveLoanOwedProvider(widget.loan.id));
    final borrowDate = widget.loan.borrowDate;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'pego em ${borrowDate.day.toString().padLeft(2, '0')}/${borrowDate.month.toString().padLeft(2, '0')}/${borrowDate.year}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            owedAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Erro: $e'),
              data: (owed) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MetricRow(
                    label: 'principal',
                    value: owed.outstandingPrincipal,
                  ),
                  _MetricRow(
                    label: 'juro acumulado',
                    value: owed.accruedInterest,
                  ),
                  _MetricRow(
                    label: 'total devido',
                    value: owed.totalOwed,
                    bold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: BrlAmountField(controller: _amountController)),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _paying ? null : _repay,
                  child: _paying
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Pagar'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(formatCurrency(value), style: style),
        ],
      ),
    );
  }
}
