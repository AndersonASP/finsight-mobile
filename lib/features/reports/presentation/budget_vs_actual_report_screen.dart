import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/providers/selected_month_provider.dart';
import '../../../core/widgets/grouped_bar_chart.dart';
import '../application/reports_providers.dart';

class BudgetVsActualReportScreen extends ConsumerWidget {
  const BudgetVsActualReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(reportsSelectedMonthProvider);
    final itemsAsync = ref.watch(budgetVsActualProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Orçado x realizado')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () =>
                      ref.read(reportsSelectedMonthProvider.notifier).state =
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
                  onPressed: () =>
                      ref.read(reportsSelectedMonthProvider.notifier).state =
                          month.nextMonth,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Erro: $error')),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nenhuma categoria com orçamento ativo neste mês.\nVincule uma tag a um item em Menu > Previsão de diário.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final overBudget = items
                    .where(
                      (i) =>
                          (double.tryParse(i.actual) ?? 0) >
                          (double.tryParse(i.budgeted) ?? 0),
                    )
                    .toList();
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GroupedBarChart(
                      xLabels: [for (final item in items) item.name],
                      series: [
                        BarSeries(
                          label: 'orçado',
                          color: Theme.of(context).colorScheme.outlineVariant,
                          values: [
                            for (final item in items)
                              double.tryParse(item.budgeted) ?? 0,
                          ],
                        ),
                        BarSeries(
                          label: 'realizado',
                          color: Theme.of(context).colorScheme.primary,
                          values: [
                            for (final item in items)
                              double.tryParse(item.actual) ?? 0,
                          ],
                        ),
                      ],
                      valueFormatter: (v) =>
                          formatCurrency(v.toStringAsFixed(2)),
                    ),
                    if (overBudget.isNotEmpty) ...[
                      const Divider(height: 32),
                      for (final item in overBudget)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${item.name}: acima do orçado',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
