import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/grouped_bar_chart.dart';
import '../../../core/widgets/today_button.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../../cards/presentation/cards_screen.dart';
import '../application/wealth_insight.dart';
import '../application/wealth_providers.dart';
import '../data/wealth.dart';
import 'asset_sheets.dart';
import 'debt_sheet.dart';

/// Patrimônio: what you have, what you owe, and — for every number — where
/// it came from ("pelos lançamentos" vs "informado por você"), so it can be
/// trusted. Informed values that got old are flagged for a quick update.
class WealthScreen extends ConsumerWidget {
  const WealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(wealthSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patrimônio'),
        leading: const TodayButton(),
        actions: [
          IconButton(
            tooltip: 'Adicionar',
            icon: const Icon(Icons.add),
            onPressed: () => _showAddMenu(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          refreshWealth(ref);
          await ref.read(wealthSummaryProvider.future);
        },
        child: summary.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erro ao carregar: $e'),
              ),
            ],
          ),
          data: (s) => _WealthBody(summary: s),
        ),
      ),
    );
  }
}

Future<void> _showAddMenu(BuildContext context, WidgetRef ref) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.trending_down),
            title: const Text('Dívida'),
            subtitle: const Text('Empréstimo, financiamento, rotativo…'),
            onTap: () => Navigator.of(sheetContext).pop('debt'),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Bem'),
            subtitle: const Text('Imóvel, veículo, outro'),
            onTap: () => Navigator.of(sheetContext).pop('asset'),
          ),
          ListTile(
            leading: const Icon(Icons.call_received),
            title: const Text('Valor a receber'),
            subtitle: const Text('Alguém te deve, reembolso, FGTS'),
            onTap: () => Navigator.of(sheetContext).pop('receivable'),
          ),
          ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: const Text('Investimento ou reserva'),
            subtitle: const Text('Crie uma conta do tipo investimento/reserva'),
            onTap: () => Navigator.of(sheetContext).pop('account'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  bool? changed;
  if (choice == 'debt') {
    changed = await showDebtSheet(context);
  } else if (choice == 'asset') {
    changed = await showAssetSheet(context, kind: AssetKind.imovel);
  } else if (choice == 'receivable') {
    changed = await showAssetSheet(context, kind: AssetKind.aReceber);
  } else {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AccountsScreen()));
    changed = true;
  }
  if (changed ?? true) refreshWealth(ref);
}

/// Walks through every informed value (stale ones first), one per sheet.
Future<void> runUpdateValuesFlow(
  BuildContext context,
  WidgetRef ref,
  WealthSummary summary,
) async {
  final items = summary.updatableItems;
  var saved = 0;
  for (var i = 0; i < items.length; i++) {
    if (!context.mounted) return;
    final result = await showUpdateValueSheet(
      context,
      items[i],
      progress: '${i + 1} de ${items.length}',
    );
    if (result == null) break; // dismissed: stop the flow
    if (result == UpdateValueResult.saved) saved++;
  }
  refreshWealth(ref);
  if (saved > 0 && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved == 1 ? '1 valor atualizado.' : '$saved valores atualizados.',
        ),
      ),
    );
  }
}

class _WealthBody extends ConsumerWidget {
  const _WealthBody({required this.summary});

  final WealthSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAnything =
        summary.assets.isNotEmpty || summary.liabilities.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.only(bottom: 140),
      children: [
        _Header(summary: summary),
        if (summary.staleCount > 0) _StaleBanner(summary: summary),
        _ReserveCard(summary: summary),
        if ((double.tryParse(summary.reserveLoansOwed) ?? 0) > 0)
          ListTile(
            dense: true,
            leading: const Icon(Icons.info_outline),
            title: Text(
              'Você deve ${formatCurrency(summary.reserveLoansOwed)} à sua reserva',
            ),
            subtitle: const Text(
              'Empréstimo de você para você — não entra nas dívidas.',
            ),
          ),
        if (!hasAnything)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Cadastre suas contas, investimentos, bens e dívidas para ver '
              'seu patrimônio. Toque em + para começar.',
              textAlign: TextAlign.center,
            ),
          ),
        if (summary.assets.isNotEmpty)
          _SideHeader(title: 'O que você tem', total: summary.totalAssets),
        for (final g in summary.assets) _GroupTile(group: g, isDebt: false),
        if (summary.liabilities.isNotEmpty)
          _SideHeader(
            title: 'O que você deve',
            total: summary.totalLiabilities,
          ),
        for (final g in summary.liabilities) _GroupTile(group: g, isDebt: true),
        const _HistoryChart(),
        if (summary.updatableItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.update),
              label: const Text('Atualizar valores'),
              onPressed: () => runUpdateValuesFlow(context, ref, summary),
            ),
          ),
      ],
    );
  }
}

/// The headline: "ficando mais rico ou mais pobre" (financial net worth, bens
/// left out), what to do about it, then the totals as supporting numbers.
class _Header extends StatelessWidget {
  const _Header({required this.summary});

  final WealthSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insight = buildWealthInsight(summary);
    final (color, icon) = switch (insight.tone) {
      InsightTone.bom => (AppColors.surplus, Icons.trending_up),
      InsightTone.ruim => (AppColors.deficit, Icons.trending_down),
      InsightTone.atencao => (Colors.amber.shade800, Icons.warning_amber),
      InsightTone.neutro => (
        theme.colorScheme.onSurfaceVariant,
        Icons.hourglass_empty,
      ),
    };
    final financial = double.tryParse(summary.financialNetWorth) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          color: color.withValues(alpha: 0.10),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        insight.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (insight.change != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    insight.change!,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (insight.changeLabel != null)
                    Text(
                      insight.changeLabel!,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
                for (final tip in insight.tips) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.chevron_right, size: 16),
                      ),
                      const SizedBox(width: 4),
                      Expanded(child: Text(tip)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _Figure(
                  label: 'Em dinheiro (sem bens)',
                  value: summary.financialNetWorth,
                  color: financial < 0 ? AppColors.deficit : null,
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'Total (com bens)',
                  value: summary.netWorth,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        Text(
          formatCurrency(value),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _StaleBanner extends ConsumerWidget {
  const _StaleBanner({required this.summary});

  final WealthSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = summary.staleCount;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: Colors.amber.withValues(alpha: 0.15),
      child: ListTile(
        leading: const Icon(Icons.schedule, color: Colors.amber),
        title: Text(
          n == 1 ? '1 valor desatualizado' : '$n valores desatualizados',
        ),
        subtitle: const Text('Leva 2 minutos e deixa os números confiáveis.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => runUpdateValuesFlow(context, ref, summary),
      ),
    );
  }
}

class _ReserveCard extends StatelessWidget {
  const _ReserveCard({required this.summary});

  final WealthSummary summary;

  @override
  Widget build(BuildContext context) {
    final months = summary.reserveMonths == null
        ? null
        : double.tryParse(summary.reserveMonths!);
    final color = months == null
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : months >= 6
        ? AppColors.surplus
        : months >= 3
        ? Colors.amber.shade700
        : AppColors.deficit;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ListTile(
        leading: Icon(Icons.shield_outlined, color: color),
        title: Text(
          months == null
              ? 'Reserva de emergência'
              : 'Sua reserva cobre ${months.toStringAsFixed(1).replaceAll('.', ',')} '
                    '${months == 1 ? 'mês' : 'meses'}',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          months == null
              ? 'Precisa de pelo menos 1 mês completo de lançamentos para calcular.'
              : 'Custo de vida médio: ${formatCurrency(summary.averageMonthlyCost!)}/mês '
                    '(últimos 3 meses). O ideal é de 6 meses para cima.',
        ),
      ),
    );
  }
}

class _SideHeader extends StatelessWidget {
  const _SideHeader({required this.title, required this.total});

  final String title;
  final String total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
          Text(
            formatCurrency(total),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group, required this.isDebt});

  final WealthGroup group;
  final bool isDebt;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(group.label),
      trailing: Text(formatCurrency(group.total)),
      children: [for (final item in group.items) WealthItemTile(item: item)],
    );
  }
}

/// One line of the patrimônio, with where its number came from.
class WealthItemTile extends ConsumerWidget {
  const WealthItemTile({super.key, required this.item});

  final WealthItem item;

  String _origin() {
    final d = item.details;
    if (item.kind == WealthItemKind.debt && d['installmentsTotal'] != null) {
      final end = d['endDate'] == null
          ? ''
          : ' · termina em ${formatMonth(DateTime.parse(d['endDate'] as String))}';
      final base =
          '${d['installmentsPaid']}/${d['installmentsTotal']} parcelas pagas$end';
      return item.source == WealthSource.informado
          ? '$base · valor para quitar informado'
          : base;
    }
    if (item.source == WealthSource.calculado) {
      return item.note ?? 'pelos lançamentos';
    }
    if (item.asOf == null) return 'nunca atualizado';
    final days = DateTime.now().difference(item.asOf!).inDays;
    return days <= 0
        ? 'informado hoje'
        : 'informado há $days ${days == 1 ? 'dia' : 'dias'}';
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    bool? changed;
    switch (item.kind) {
      case WealthItemKind.debt:
        changed = await showDebtSheet(
          context,
          debtId: item.id,
          installmentsPaid: item.details['installmentsPaid'] as int?,
        );
      case WealthItemKind.asset:
        changed = await showAssetSheet(context, existing: item);
      case WealthItemKind.account:
        if (item.source == WealthSource.informado) {
          changed =
              await showUpdateValueSheet(context, item) ==
              UpdateValueResult.saved;
        }
      case WealthItemKind.card:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CardsScreen()));
        changed = true;
    }
    if (changed == true) refreshWealth(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final interest = item.details['monthlyInterestCost'] as String?;
    final tappable =
        item.kind != WealthItemKind.account ||
        item.source == WealthSource.informado;
    return ListTile(
      onTap: tappable ? () => _open(context, ref) : null,
      title: Text(item.name),
      subtitle: Text(
        [
          _origin(),
          if (interest != null) '~${formatCurrency(interest)}/mês de juros',
        ].join('\n'),
      ),
      isThreeLine: interest != null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.stale)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: 'Desatualizado',
                child: Icon(
                  Icons.circle,
                  size: 8,
                  color: Colors.amber.shade700,
                ),
              ),
            ),
          Text(formatCurrency(item.value), style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _HistoryChart extends ConsumerWidget {
  const _HistoryChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(wealthHistoryProvider).value ?? const [];
    if (points.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Evolução', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          GroupedBarChart(
            xLabels: [for (final p in points) formatMonth(p.month)],
            series: [
              BarSeries(
                label: 'patrimônio líquido',
                color: AppColors.metaAcima,
                values: [
                  for (final p in points) double.tryParse(p.netWorth) ?? 0,
                ],
              ),
            ],
            valueFormatter: (v) => formatCurrency(v.toStringAsFixed(0)),
          ),
        ],
      ),
    );
  }
}
