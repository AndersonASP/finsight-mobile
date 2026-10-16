import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/providers/selected_month_provider.dart';
import '../../../core/widgets/horizontal_bar_list.dart';
import '../application/reports_providers.dart';

Color _parseCategoryColor(String hex) =>
    Color(int.parse(hex.replaceFirst('#', '0xFF')));

class CategoryBreakdownReportScreen extends ConsumerWidget {
  const CategoryBreakdownReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(reportsSelectedMonthProvider);
    final itemsAsync = ref.watch(categoryBreakdownProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gastos por categoria')),
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
                    child: Text('Nenhum gasto com categoria neste mês.'),
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
                            color: _parseCategoryColor(item.color),
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
