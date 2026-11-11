import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/today_button.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../../cards/presentation/cards_screen.dart';
import '../application/wealth_insight.dart';
import '../application/wealth_providers.dart';
import '../data/wealth.dart';
import 'asset_sheets.dart';
import 'debt_sheet.dart';
import 'goals_screen.dart';

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
    final insight = buildWealthInsight(summary);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
      children: [
        _Hero(summary: summary, insight: insight),
        if (summary.staleCount > 0) ...[
          const SizedBox(height: 12),
          _StaleBanner(summary: summary),
        ],
        if (insight.tips.isNotEmpty) ...[
          const SizedBox(height: 12),
          _NextSteps(tips: insight.tips),
        ],
        const SizedBox(height: 12),
        _HealthCard(summary: summary),
        for (final c in summary.diagnosis.concentration) ...[
          const SizedBox(height: 12),
          _Note(
            icon: CupertinoIcons.chart_pie,
            title:
                '${c.percent}% da ${c.bloco == 'reserva' ? 'reserva' : 'carteira de investimentos'} está em ${c.item}',
            body:
                'Com um valor relevante, vale diversificar entre instituições '
                'e produtos. É só uma informação — o perfil é seu.',
          ),
        ],
        if ((double.tryParse(summary.reserveLoansOwed) ?? 0) > 0) ...[
          const SizedBox(height: 12),
          _Note(
            icon: CupertinoIcons.info,
            title:
                'Você deve ${formatCurrency(summary.reserveLoansOwed)} à sua reserva',
            body: 'Empréstimo de você para você — não entra nas dívidas.',
          ),
        ],
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
          _Section(
            title: 'O que você tem',
            total: summary.totalAssets,
            groups: summary.assets,
          ),
        if (summary.liabilities.isNotEmpty)
          _Section(
            title: 'Saldo devedor',
            total: summary.totalLiabilities,
            groups: summary.liabilities,
          ),
        if (summary.commitments.isNotEmpty)
          _Section(
            title: 'Compromissos do cartão',
            total: summary.cardCommitments,
            groups: summary.commitments,
            caption:
                'Parcelas a vencer de compras já feitas. Não são saldo devedor '
                '(não entram no % líquido), mas já saem do seu dinheiro livre.',
          ),
        if (summary.updatableItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: FilledButton.tonalIcon(
              icon: const Icon(CupertinoIcons.arrow_2_circlepath, size: 18),
              label: const Text('Atualizar valores'),
              onPressed: () => runUpdateValuesFlow(context, ref, summary),
            ),
          ),
      ],
    );
  }
}

/// The headline: the total patrimônio líquido (bens included — método R7),
/// whether it is growing, and its evolution as a sparkline.
class _Hero extends ConsumerWidget {
  const _Hero({required this.summary, required this.insight});

  final WealthSummary summary;
  final WealthInsight insight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (color, icon) = switch (insight.tone) {
      InsightTone.bom => (AppColors.surplus, CupertinoIcons.arrow_up_right),
      InsightTone.ruim => (AppColors.deficit, CupertinoIcons.arrow_down_right),
      InsightTone.atencao => (
        Colors.amber.shade800,
        CupertinoIcons.exclamationmark_triangle,
      ),
      InsightTone.neutro => (
        theme.colorScheme.onSurfaceVariant,
        CupertinoIcons.hourglass,
      ),
    };
    final points = ref.watch(wealthHistoryProvider).value ?? const [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PATRIMÔNIO LÍQUIDO', style: AppText.eyebrow(context)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatCurrency(summary.netWorth),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  fontFeatures: AppText.tabularFigures,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      insight.title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (insight.change != null) ...[
              const SizedBox(height: 10),
              Text(
                insight.change!,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontFeatures: AppText.tabularFigures,
                ),
              ),
              if (insight.changeLabel != null)
                Text(
                  insight.changeLabel!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
            if (points.length >= 2) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                child: CustomPaint(
                  size: const Size.fromHeight(56),
                  painter: _SparklinePainter(
                    values: [
                      for (final p in points) double.tryParse(p.netWorth) ?? 0,
                    ],
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatMonth(points.first.month),
                    style: theme.textTheme.labelSmall,
                  ),
                  Text(
                    formatMonth(points.last.month),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = max - min == 0 ? 1.0 : max - min;
    const pad = 4.0;
    Offset at(int i) => Offset(
      i / (values.length - 1) * size.width,
      pad + (1 - (values[i] - min) / range) * (size.height - pad * 2),
    );
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(at(values.length - 1), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}

class _StaleBanner extends ConsumerWidget {
  const _StaleBanner({required this.summary});

  final WealthSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = summary.staleCount;
    final theme = Theme.of(context);
    return Card(
      color: Colors.amber.withValues(alpha: 0.14),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => runUpdateValuesFlow(context, ref, summary),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(CupertinoIcons.clock, color: Colors.amber.shade800),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n == 1
                          ? '1 valor desatualizado'
                          : '$n valores desatualizados',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Leva 2 minutos e deixa os números confiáveis.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(CupertinoIcons.chevron_right, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// What to do now, most important first (the método's order).
class _NextSteps extends StatelessWidget {
  const _NextSteps({required this.tips});

  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PRÓXIMOS PASSOS', style: AppText.eyebrow(context)),
            for (var i = 0; i < tips.length; i++) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tips[i],
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The three gauges of the método in one place: reserve, % líquido and the
/// free cash. Each is one line + one bar; the long explanation lives behind
/// a tap.
class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.summary});

  final WealthSummary summary;

  @override
  Widget build(BuildContext context) {
    final months = summary.reserveMonths == null
        ? null
        : double.tryParse(summary.reserveMonths!);
    final target = summary.reserveTargetMonths;
    final reserveColor = months == null
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : summary.reserveComplete
        ? AppColors.surplus
        : months >= 3
        ? Colors.amber.shade700
        : AppColors.deficit;
    final missing = double.tryParse(summary.reserveMissing ?? '') ?? 0;

    final percent = double.tryParse(summary.netWorthPercent ?? '');
    final alert = summary.netWorthAlert;
    final percentColor = alert ? AppColors.deficit : AppColors.surplus;
    final minPercent = summary.netWorthMinPercent;

    final financial = double.tryParse(summary.financialNetWorth) ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            _Gauge(
              label: 'Reserva de emergência',
              value: months == null
                  ? 'Sem dados'
                  : '${months.toStringAsFixed(1).replaceAll('.', ',')} de $target meses',
              color: reserveColor,
              progress: months == null ? null : months / target,
              caption: months == null
                  ? 'Precisa de pelo menos 1 mês completo de lançamentos.'
                  : missing > 0
                  ? 'Faltam ${formatCurrency(summary.reserveMissing!)} · '
                        'custo de vida ${formatCurrency(summary.averageMonthlyCost!)}/mês'
                  : 'Meta atingida · custo de vida '
                        '${formatCurrency(summary.averageMonthlyCost!)}/mês',
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const GoalsScreen())),
            ),
            if (percent != null) ...[
              const _GaugeDivider(),
              _Gauge(
                label: 'Parte que é sua',
                value: '${percent.toStringAsFixed(1).replaceAll('.', ',')}%',
                color: percentColor,
                progress: percent / 100,
                marker: minPercent / 100,
                caption: alert
                    ? 'Abaixo de $minPercent%: boa parte do que você tem ainda é do banco.'
                    : 'Acima de $minPercent%, como deve ser.',
                onTap: () => _explain(
                  context,
                  'Parte que é sua',
                  'É o patrimônio líquido dividido pelo total do que você '
                      'tem (patrimônio − saldo devedor, sobre o patrimônio). '
                      'O farol acende abaixo de $minPercent%.\n\n'
                      '${alert ? 'Evite novas dívidas e ${summary.reserveComplete ? 'use a sobra para amortizar parcelas.' : 'guarde mais até completar a reserva.'}' : 'Continue mantendo as dívidas sob controle.'}',
                ),
              ),
            ],
            const _GaugeDivider(),
            _Gauge(
              label: 'Livre em dinheiro',
              value: formatCurrency(summary.financialNetWorth),
              color: financial < 0 ? AppColors.deficit : null,
              caption: 'Sem bens e já descontando as parcelas do cartão.',
              onTap: () => _explain(
                context,
                'Livre em dinheiro',
                'É o que você teria em dinheiro se vendesse tudo o que é '
                    'financeiro e pagasse o que deve — sem contar bens (carro, '
                    'imóvel), que não pagam boletos, e já descontando as '
                    'parcelas do cartão que ainda vão vencer.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _explain(BuildContext context, String title, String body) {
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(body, style: const TextStyle(height: 1.4)),
          ],
        ),
      ),
    ),
  );
}

class _GaugeDivider extends StatelessWidget {
  const _GaugeDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Divider(),
  );
}

class _Gauge extends StatelessWidget {
  const _Gauge({
    required this.label,
    required this.value,
    required this.caption,
    this.color,
    this.progress,
    this.marker,
    this.onTap,
  });

  final String label;
  final String value;
  final String caption;
  final Color? color;

  /// 0..1 fill; null hides the bar.
  final double? progress;

  /// 0..1 position of a threshold tick on the bar.
  final double? marker;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontFeatures: AppText.tabularFigures,
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            _Bar(
              progress: progress!.clamp(0.0, 1.0),
              marker: marker,
              color: color ?? theme.colorScheme.primary,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.progress, required this.color, this.marker});

  final double progress;
  final double? marker;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.outlineVariant;
    return LayoutBuilder(
      builder: (context, c) => SizedBox(
        height: 10,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: track,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              height: 8,
              width: c.maxWidth * progress,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            if (marker != null)
              Positioned(
                left: c.maxWidth * marker!.clamp(0.0, 1.0) - 1,
                child: Container(
                  width: 2,
                  height: 10,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One side of the balance sheet: a header with the total and a single card
/// with every group (sub-header + items) inside.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.total,
    required this.groups,
    this.caption,
  });

  final String title;
  final String total;
  final List<WealthGroup> groups;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 28, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Text(
                formatCurrency(total),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: AppText.tabularFigures,
                ),
              ),
            ],
          ),
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              caption!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final g in groups)
          if (g.items.isNotEmpty || groups.length == 1) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      g.label.toUpperCase(),
                      style: AppText.eyebrow(context),
                    ),
                  ),
                  Text(
                    formatCurrency(g.total),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: AppText.tabularFigures,
                    ),
                  ),
                ],
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < g.items.length; i++) ...[
                    if (i > 0) const Divider(indent: 68),
                    WealthItemTile(item: g.items[i]),
                  ],
                ],
              ),
            ),
          ],
      ],
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
    final informed = days <= 0
        ? 'informado hoje'
        : 'informado há $days ${days == 1 ? 'dia' : 'dias'}';
    final owed = d['debtOutstanding'] as String?;
    return owed == null
        ? informed
        : '$informed · financiado: deve ${formatCurrency(owed)}, '
              'seu ${formatCurrency(d['equity'] as String)}';
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

  (IconData, Color) _badge() => switch (item.kind) {
    WealthItemKind.account => (CupertinoIcons.money_dollar, AppColors.entrada),
    WealthItemKind.asset => (CupertinoIcons.house, AppColors.metaAcima),
    WealthItemKind.debt => (CupertinoIcons.arrow_down_right, AppColors.saida),
    WealthItemKind.card => (CupertinoIcons.creditcard, AppColors.cartao),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final interest = item.details['monthlyInterestCost'] as String?;
    final tappable =
        item.kind != WealthItemKind.account ||
        item.source == WealthSource.informado;
    final (icon, tint) = _badge();
    return InkWell(
      onTap: tappable ? () => _open(context, ref) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: tint),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      _origin(),
                      if (interest != null)
                        '~${formatCurrency(interest)}/mês de juros',
                    ].join('\n'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
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
            Text(
              formatCurrency(item.value),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: AppText.tabularFigures,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
