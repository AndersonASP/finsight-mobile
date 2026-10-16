import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/widgets/brl_amount_field.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../accounts/data/account.dart';
import '../../ledger/application/ledger_providers.dart';
import '../../totals/application/totals_providers.dart';
import '../application/invoices_providers.dart';
import '../data/invoice.dart';
import '../data/invoice_payments_repository.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(invoiceDetailProvider(invoiceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Fatura')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (detail) {
          final invoice = detail.invoice;
          final canPay = invoice.status != InvoiceStatus.paid;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${invoice.periodMonth.toString().padLeft(2, '0')}/${invoice.periodYear}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(invoice.status.label),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('total'),
                        Text(formatCurrency(invoice.total)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('pago'),
                        Text(formatCurrency(invoice.paid)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'restante',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          formatCurrency(invoice.remaining),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (canPay) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Pagar fatura'),
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => _PayInvoiceSheet(
                            invoiceId: invoiceId,
                            remaining: invoice.remaining,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: detail.installments.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final line = detail.installments[index];
                    return ListTile(
                      title: Text(line.purchaseDescription),
                      subtitle: Text('parcela ${line.sequence}'),
                      trailing: Text(formatCurrency(line.amount)),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PayInvoiceSheet extends ConsumerStatefulWidget {
  const _PayInvoiceSheet({required this.invoiceId, required this.remaining});

  final String invoiceId;
  final String remaining;

  @override
  ConsumerState<_PayInvoiceSheet> createState() => _PayInvoiceSheetState();
}

class _PayInvoiceSheetState extends ConsumerState<_PayInvoiceSheet> {
  late final TextEditingController _amountController = TextEditingController(
    text: BrlAmountField.fromApiAmount(widget.remaining),
  );
  final _interestController = TextEditingController();
  String? _accountId;
  DateTime _paymentDate = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = BrlAmountField.toApiAmount(_amountController.text);
    if (_accountId == null || amount == null) {
      setState(() => _error = 'Preencha conta e valor.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final interest = BrlAmountField.toApiAmount(_interestController.text);
      await ref
          .read(invoicePaymentsRepositoryProvider)
          .create(
            invoiceId: widget.invoiceId,
            accountId: _accountId!,
            paymentDate: _paymentDate,
            amount: amount,
            interestAmount: interest,
          );
      ref.invalidate(invoiceDetailProvider(widget.invoiceId));
      ref.invalidate(dailyBalanceProvider);
      ref.invalidate(monthlyTotalsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Não foi possível registrar o pagamento: $e');
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pagar fatura', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            accountsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Erro ao carregar contas: $e'),
              data: (accounts) => DropdownButtonFormField<String>(
                initialValue: accounts.any((a) => a.id == _accountId)
                    ? _accountId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Pagar com a conta',
                ),
                items: accounts
                    .map(
                      (Account a) =>
                          DropdownMenuItem(value: a.id, child: Text(a.name)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _accountId = value),
              ),
            ),
            const SizedBox(height: 12),
            BrlAmountFormField(
              controller: _amountController,
              labelText: 'Valor a pagar',
            ),
            const SizedBox(height: 12),
            BrlAmountFormField(
              controller: _interestController,
              labelText: 'Juros/encargos (opcional)',
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data do pagamento'),
              trailing: Text(
                '${_paymentDate.day.toString().padLeft(2, '0')}/${_paymentDate.month.toString().padLeft(2, '0')}/${_paymentDate.year}',
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _paymentDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _paymentDate = picked);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirmar pagamento'),
            ),
          ],
        ),
      ),
    );
  }
}
