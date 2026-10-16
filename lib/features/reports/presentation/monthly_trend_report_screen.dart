import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/grouped_bar_chart.dart';
import '../application/reports_providers.dart';

class MonthlyTrendReportScreen extends ConsumerWidget {
  const MonthlyTrendReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointsAsync = ref.watch(monthlyTrendProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Evolução mensal')),
      body: pointsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (points) {
          if (points.isEmpty) {
            return const Center(child: Text('Sem dados ainda.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'entradas x saídas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              GroupedBarChart(
                xLabels: [for (final p in points) formatMonth(p.asDate)],
                series: [
                  BarSeries(
                    label: 'entradas',
                    color: AppColors.entrada,
                    values: [
                      for (final p in points) double.tryParse(p.entradas) ?? 0,
                    ],
                  ),
                  BarSeries(
                    label: 'saídas',
                    color: AppColors.saida,
                    values: [
                      for (final p in points) double.tryParse(p.saidas) ?? 0,
                    ],
                  ),
                ],
                valueFormatter: (v) => formatCurrency(v.toStringAsFixed(2)),
              ),
              const Divider(height: 32),
              Text(
                'saldo (contas corrente) no fim de cada mês',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final point in points)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(formatMonth(point.asDate)),
                  trailing: Text(
                    formatCurrency(point.saldoFinal),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
