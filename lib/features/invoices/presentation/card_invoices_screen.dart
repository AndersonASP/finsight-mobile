import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../cards/data/fin_card.dart';
import '../application/invoices_providers.dart';
import '../data/invoice.dart';
import 'invoice_detail_screen.dart';

class CardInvoicesScreen extends ConsumerWidget {
  const CardInvoicesScreen({super.key, required this.card});

  final FinCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(cardInvoicesProvider(card.id));

    return Scaffold(
      appBar: AppBar(title: Text(card.name)),
      body: invoicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (invoices) {
          if (invoices.isEmpty) return const Center(child: Text('Nenhuma fatura ainda.'));
          return ListView.separated(
            itemCount: invoices.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final invoice = invoices[index];
              return ListTile(
                title: Text('${invoice.periodMonth.toString().padLeft(2, '0')}/${invoice.periodYear}'),
                subtitle: Text(invoice.status.label),
                trailing: Text(formatCurrency(invoice.total), style: Theme.of(context).textTheme.titleMedium),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: invoice.id))),
              );
            },
          );
        },
      ),
    );
  }
}
