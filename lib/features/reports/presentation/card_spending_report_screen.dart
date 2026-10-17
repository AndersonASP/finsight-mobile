import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/providers/selected_month_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/horizontal_bar_list.dart';
import '../application/reports_providers.dart';

class CardSpendingReportScreen extends ConsumerWidget {
  const CardSpendingReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(reportsSelectedMonthProvider);
    final showAnnual = ref.watch(cardSpendingShowAnnualProvider);
    final itemsAsync = ref.watch(cardSpendingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gastos por cartão')),
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
                      ref
                          .read(reportsSelectedMonthProvider.notifier)
                          .state = showAnnual
                      ? DateTime(month.year - 1, month.month)
                      : month.previousMonth,
                ),
                Text(
                  showAnnual ? '${month.year}' : formatMonth(month),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () =>
                      ref
                          .read(reportsSelectedMonthProvider.notifier)
                          .state = showAnnual
                      ? DateTime(month.year + 1, month.month)
                      : month.nextMonth,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Mês')),
                ButtonSegment(value: true, label: Text('Ano')),
              ],
              selected: {showAnnual},
              onSelectionChanged: (selection) =>
                  ref.read(cardSpendingShowAnnualProvider.notifier).state =
                      selection.first,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Erro: $error')),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text('Nenhum gasto com cartão neste período.'),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    HorizontalBarList(
                      items: [
                        for (final item in items)
                          HorizontalBarItem(
                            label: item.name,
                            value: double.tryParse(item.total) ?? 0,
                            valueLabel: formatCurrency(item.total),
                            color: AppColors.cartao,
                          ),
                      ],
                    ),
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
