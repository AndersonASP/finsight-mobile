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
          if (invoices.isEmpty) {
            return const Center(child: Text('Nenhuma fatura ainda.'));
          }
          // Newest first (as the API sends them), one section per year.
          final rows = <Object>[];
          for (final invoice in invoices) {
            if (rows.isEmpty ||
                (rows.last is Invoice &&
                    (rows.last as Invoice).periodYear != invoice.periodYear)) {
              rows.add(invoice.periodYear);
            }
            rows.add(invoice);
          }
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              if (row is int) return _YearHeader(year: row);
              final invoice = row as Invoice;
              return ListTile(
                title: Text(invoice.monthName),
                subtitle: Text(
                  '${invoice.status.label} · vence ${invoice.dueDate.day.toString().padLeft(2, '0')}/${invoice.dueDate.month.toString().padLeft(2, '0')}',
                ),
                trailing: Text(
                  formatCurrency(invoice.total),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => InvoiceDetailScreen(invoiceId: invoice.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _YearHeader extends StatelessWidget {
  const _YearHeader({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Text(
        '$year',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
