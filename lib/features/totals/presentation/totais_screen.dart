import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../reports/presentation/category_breakdown_report_screen.dart';
import '../../../core/format/money.dart';
import '../../../core/providers/selected_month_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/today_button.dart';
import '../application/totals_providers.dart';
import '../../reports/data/daily_balance_day.dart';

class TotaisScreen extends ConsumerWidget {
  const TotaisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final totalsAsync = ref.watch(monthlyTotalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Totais'),
        leading: const TodayButton(),
        actions: [
          // The one report used often enough to keep a door to it.
          IconButton(
            tooltip: 'Gastos por tag',
            icon: const Icon(Icons.donut_large_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CategoryBreakdownReportScreen(),
              ),
            ),
          ),
        ],
      ),
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
                      ref.read(selectedMonthProvider.notifier).state =
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
                      ref.read(selectedMonthProvider.notifier).state =
                          month.nextMonth,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: totalsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Erro: $error')),
              data: (totals) => _TotalsBody(totals: totals),
            ),
          ),
        ],
      ),
    );
  }
}

/// The app's savings target is a fixed 20–30% band (not something the user
/// configures per period) — "economizado" below is just compared against it.
const _savingsGoalMinPercent = 20.0;
const _savingsGoalMaxPercent = 30.0;

String _savingsGoalStatusText(double percent) {
  if (percent < _savingsGoalMinPercent) return 'abaixo da meta (20% a 30%)';
  if (percent > _savingsGoalMaxPercent) return 'acima da meta (20% a 30%)';
  return 'dentro da meta (20% a 30%)';
}

class _TotalsBody extends StatelessWidget {
  const _TotalsBody({required this.totals});

  final MonthlyTotals totals;

  @override
  Widget build(BuildContext context) {
    final performance = double.parse(totals.performance);
    final economizadoPercent = double.parse(
      totals.economizadoPercent,
    ).clamp(0, 100).toDouble();
    final withinSavingsGoal =
        economizadoPercent >= _savingsGoalMinPercent &&
        economizadoPercent <= _savingsGoalMaxPercent;

    return ListView(
      children: [
        const _SectionLabel('cálculos do mês'),
        ListTile(
          title: const Text('performance'),
          subtitle: Text(
            performance < 0 ? 'faltou dinheiro' : 'sobrou dinheiro',
          ),
          trailing: Text(
            formatCurrency(totals.performance),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: performance < 0 ? AppColors.deficit : AppColors.surplus,
            ),
          ),
        ),
        ListTile(
          title: const Text('economizado'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 160,
                child: LinearProgressIndicator(
                  value: economizadoPercent / 100,
                  color: AppColors.economia,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    withinSavingsGoal
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _savingsGoalStatusText(economizadoPercent),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          trailing: Text(
            formatPercent(totals.economizadoPercent),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ListTile(
          title: const Text('custo de vida'),
          subtitle: Text(
            totals.rendaExcedeCustoDeVida
                ? 'dentro da renda'
                : 'acima da renda',
          ),
          trailing: Text(
            formatCurrency(totals.custoDeVida),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ListTile(
          title: const Text('diário médio'),
          subtitle: Text(
            'previsto ${formatCurrency(totals.diarioMedioPrevisto)}',
          ),
          trailing: Text(
            formatCurrency(totals.diarioMedioRealizado),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(),
        const _SectionLabel('movimentações do mês'),
        ListTile(
          leading: const Icon(
            Icons.south_west_rounded,
            color: AppColors.entrada,
          ),
          title: const Text('entradas'),
          trailing: Text(
            formatCurrency(totals.entradas),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.north_east_rounded, color: AppColors.saida),
          title: const Text('saídas'),
          trailing: Text(
            formatCurrency(totals.saidas),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ListTile(
          leading: const Icon(
            Icons.shopping_bag_outlined,
            color: AppColors.diario,
          ),
          title: const Text('diário'),
          trailing: Text(
            formatCurrency(totals.diario),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ListTile(
          leading: const Icon(
            Icons.savings_outlined,
            color: AppColors.economia,
          ),
          title: const Text('economia'),
          trailing: Text(
            formatCurrency(totals.economia),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
