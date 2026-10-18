import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../application/invoices_providers.dart';
import '../data/invoice.dart';

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
                          '${invoice.monthName} de ${invoice.periodYear}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(invoice.status.label),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'total',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          formatCurrency(invoice.total),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('vencimento'),
                        Text(
                          '${invoice.dueDate.day.toString().padLeft(2, '0')}/${invoice.dueDate.month.toString().padLeft(2, '0')}/${invoice.dueDate.year}',
                        ),
                      ],
                    ),
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
