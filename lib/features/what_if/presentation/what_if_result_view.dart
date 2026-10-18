import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../data/what_if.dart';

Color verdictColor(WhatIfVerdict verdict) => switch (verdict) {
  WhatIfVerdict.cabe => AppColors.surplus,
  WhatIfVerdict.aperta => const Color(0xFFB8860B),
  WhatIfVerdict.furaReserva => AppColors.saida,
  WhatIfVerdict.naoCabe => AppColors.saldoDarkRed,
};

IconData verdictIcon(WhatIfVerdict verdict) => switch (verdict) {
  WhatIfVerdict.cabe => Icons.check_circle_outline,
  WhatIfVerdict.aperta => Icons.error_outline,
  WhatIfVerdict.furaReserva => Icons.shield_outlined,
  WhatIfVerdict.naoCabe => Icons.block,
};

final _dayFormat = DateFormat("d/MMM", 'pt_BR');
final _dayYearFormat = DateFormat("d/MMM/yy", 'pt_BR');

/// "2026-10-31" → "31/out"; another year → "14/ago/27".
String _shortDate(String iso) {
  final date = DateTime.parse(iso);
  final format = date.year == DateTime.now().year ? _dayFormat : _dayYearFormat;
  return format.format(date).replaceAll('.', '');
}

double _num(String? value) => double.tryParse(value ?? '') ?? 0;

/// Whole reais ("R$ 6.990"): the result screen is read at a glance.
final _brl = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: 'R\$',
  decimalDigits: 0,
);
String _money(String? value) => _brl.format(_num(value));

class VerdictChip extends StatelessWidget {
  const VerdictChip(this.verdict, {super.key});

  final WhatIfVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final color = verdictColor(verdict);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(verdictIcon(verdict), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            verdict.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The answer to "E se?" on its own page: the verdict and the saldo first,
/// everything else below; the actions stay pinned at the bottom.
class WhatIfResultScreen extends StatefulWidget {
  const WhatIfResultScreen({
    super.key,
    required this.result,
    this.title,
    this.onSave,
    this.onLaunch,
  });

  final WhatIfResult result;
  final String? title;

  /// Saves to "Quero comprar"; returns whether it worked.
  final Future<bool> Function()? onSave;

  /// Opens the real lançamento form for the chosen option.
  final VoidCallback? onLaunch;

  @override
  State<WhatIfResultScreen> createState() => _WhatIfResultScreenState();
}

class _WhatIfResultScreenState extends State<WhatIfResultScreen> {
  bool _saving = false;
  bool _saved = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await widget.onSave!();
    if (mounted) {
      setState(() {
        _saving = false;
        _saved = ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final canSave = widget.onSave != null && !result.recorrente;
    final hasActions = canSave || widget.onLaunch != null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? result.descricao ?? 'E se?')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [WhatIfResultView(result: result)],
      ),
      bottomNavigationBar: !hasActions
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  if (canSave)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saved || _saving ? null : _save,
                        icon: Icon(
                          _saved ? Icons.bookmark : Icons.bookmark_add_outlined,
                        ),
                        label: Text(
                          _saved
                              ? 'Em Quero comprar'
                              : 'Salvar em Quero comprar',
                        ),
                      ),
                    ),
                  if (canSave && widget.onLaunch != null)
                    const SizedBox(width: 8),
                  if (widget.onLaunch != null)
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: widget.onLaunch,
                        child: const Text('Comprei'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// Verdict hero, the saldo before × after (with a small chart), three key
/// figures, then the reasons, the paths, the options and the month-by-month.
/// Every number and sentence comes from the server.
class WhatIfResultView extends StatelessWidget {
  const WhatIfResultView({super.key, required this.result});

  final WhatIfResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chosen = result.escolhida;
    // The translation already has its own tile.
    final motivos = result.motivos
        .where((m) => result.diasDeDiario == null || !m.startsWith('Equivale'))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hero(result: result),
        if (result.plano != null) ...[
          const SizedBox(height: 12),
          _PlanCard(plan: result.plano!, metaPercent: result.metaPercent),
        ],
        const SizedBox(height: 12),
        _SaldoCard(result: result),
        const SizedBox(height: 12),
        _KeyFigures(result: result),
        if (motivos.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionTitle('Por quê'),
          for (final motivo in motivos)
            _Bullet(text: motivo, color: verdictColor(result.verdict)),
        ],
        if (result.caminhos.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionTitle('Caminhos que respeitam sua reserva'),
          for (final caminho in result.caminhos)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.subdirectory_arrow_right,
                      size: 20,
                      color: AppColors.surplus,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(caminho)),
                  ],
                ),
              ),
            ),
        ],
        if (result.decidido && result.opcoes.length > 1) ...[
          const SizedBox(height: 24),
          const _SectionTitle('Opções comparadas'),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final option in result.opcoes)
                  _OptionRow(
                    option: option,
                    best: identical(option, result.opcoes.first),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Mês a mês (${chosen.label})',
              style: theme.textTheme.titleSmall,
            ),
            children: [
              for (final month in chosen.meses)
                _MonthRow(month: month, metaPercent: result.metaPercent),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.result});

  final WhatIfResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = verdictColor(result.verdict);
    final chosen = result.escolhida;
    final how = chosen.parcelas > 1
        ? '${chosen.label} de ${_money(chosen.valorParcela)}'
        : chosen.label;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.30),
            color.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(verdictIcon(result.verdict), color: color, size: 22),
              const SizedBox(width: 6),
              Text(
                result.verdict.label.toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            result.manchete,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            [
              _money(result.valor) + (result.recorrente ? '/mês' : ''),
              how,
            ].join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// "O que você precisa": each server sentence as a step, its "Agora:" /
/// "Todo mês:" prefix in bold, and the monthly total up top.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.metaPercent});

  final WhatIfPlan plan;
  final String metaPercent;

  static IconData _iconFor(String line) {
    if (line.startsWith('Agora')) return Icons.bolt_outlined;
    if (line.startsWith('Todo mês')) return Icons.trending_down;
    if (line.startsWith('Para a')) return Icons.shopping_bag_outlined;
    if (line.startsWith('Ao todo')) return Icons.functions;
    return Icons.subdirectory_arrow_right;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final accent = theme.colorScheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, color: accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'O que você precisa',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Para comprar sem ficar no vermelho e guardando $metaPercent%',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            if (_num(plan.porMes) > 0) ...[
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _money(plan.porMes),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                      TextSpan(
                        text: ' /mês',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                'a menos de gastos ou a mais de entrada',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
            const SizedBox(height: 8),
            for (final line in plan.linhas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_iconFor(line), size: 18, color: muted),
                    const SizedBox(width: 10),
                    Expanded(child: _PrefixBold(line)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Agora: R$ 2.433 …" with "Agora:" in bold.
class _PrefixBold extends StatelessWidget {
  const _PrefixBold(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colon = text.indexOf(':');
    if (colon <= 0 || colon > 20) return Text(text);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: text.substring(0, colon + 1),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: text.substring(colon + 1)),
        ],
      ),
    );
  }
}

/// Lowest projected saldo without the purchase × with it, and the monthly
/// lowest saldo of both as two lines.
class _SaldoCard extends StatelessWidget {
  const _SaldoCard({required this.result});

  final WhatIfResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final months = result.escolhida.meses;

    // Both figures are the same day: the lowest saldo once the purchase has
    // been paid, with and without it.
    final after = result.escolhida.menorSaldo;
    final before = result.escolhida.menorSaldoSemACompra;
    final date = result.escolhida.menorSaldoData;
    final dateLabel = date == null ? null : _shortDate(date);
    final color = verdictColor(result.verdict);

    Color tone(String? v) =>
        _num(v) < 0 ? AppColors.saldoDarkRed : theme.colorScheme.onSurface;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seu saldo mais baixo depois de pagar',
              style: theme.textTheme.titleSmall?.copyWith(color: muted),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _Figure(
                    label: 'Sem a compra',
                    value: before == null ? '—' : _money(before),
                    color: tone(before),
                    caption: dateLabel,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 22, right: 8),
                  child: Icon(Icons.arrow_forward, color: muted, size: 20),
                ),
                Expanded(
                  child: _Figure(
                    label: 'Com a compra',
                    value: after == null ? '—' : _money(after),
                    color: tone(after),
                    caption: dateLabel,
                    emphasized: true,
                  ),
                ),
              ],
            ),
            if (months.length > 1) ...[
              const SizedBox(height: 14),
              _SaldoChart(months: months, color: color),
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _Legend(color: muted, label: 'sem a compra', dashed: true),
                  _Legend(color: color, label: 'com a compra'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.color,
    this.caption,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Color color;
  final String? caption;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style:
                (emphasized
                        ? theme.textTheme.headlineSmall
                        : theme.textTheme.titleLarge)
                    ?.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          caption ?? '',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 3,
        color: dashed ? color.withValues(alpha: 0.6) : color,
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class _SaldoChart extends StatelessWidget {
  const _SaldoChart({required this.months, required this.color});

  final List<WhatIfMonth> months;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // Month labels: at most ~6 so they never collide.
    final step = (months.length / 6).ceil();
    return Column(
      children: [
        SizedBox(
          height: 110,
          width: double.infinity,
          child: CustomPaint(
            painter: _SaldoPainter(
              before: [for (final m in months) _maybe(m.menorSaldoAntes)],
              after: [for (final m in months) _maybe(m.menorSaldoDepois)],
              color: color,
              muted: muted,
              negative: AppColors.saldoDarkRed,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < months.length; i++)
              Expanded(
                child: Text(
                  i % step == 0 ? formatMonth(months[i].month) : '',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
              ),
          ],
        ),
      ],
    );
  }

  static double? _maybe(String? v) => v == null ? null : double.tryParse(v);
}

class _SaldoPainter extends CustomPainter {
  _SaldoPainter({
    required this.before,
    required this.after,
    required this.color,
    required this.muted,
    required this.negative,
  });

  final List<double?> before;
  final List<double?> after;
  final Color color;
  final Color muted;
  final Color negative;

  @override
  void paint(Canvas canvas, Size size) {
    final values = [...before, ...after].whereType<double>().toList();
    if (values.isEmpty) return;
    var lo = math.min(0.0, values.reduce(math.min));
    var hi = math.max(0.0, values.reduce(math.max));
    if (hi == lo) hi = lo + 1;
    final pad = (hi - lo) * 0.08;
    lo -= pad;
    hi += pad;

    final slot = size.width / before.length;
    double x(int i) => slot * i + slot / 2;
    double y(double v) => size.height - (v - lo) / (hi - lo) * size.height;

    // Below zero: a faint red band, so a negative saldo reads at a glance.
    final zero = y(0);
    if (lo < 0) {
      canvas.drawRect(
        Rect.fromLTRB(0, zero, size.width, size.height),
        Paint()..color = negative.withValues(alpha: 0.10),
      );
    }
    final axis = Paint()
      ..color = muted.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var dx = 0.0; dx < size.width; dx += 8) {
      canvas.drawLine(Offset(dx, zero), Offset(dx + 4, zero), axis);
    }

    void line(List<double?> series, Paint paint, {bool dots = false}) {
      final path = Path();
      var started = false;
      for (var i = 0; i < series.length; i++) {
        final v = series[i];
        if (v == null) continue;
        final p = Offset(x(i), y(v));
        started ? path.lineTo(p.dx, p.dy) : path.moveTo(p.dx, p.dy);
        started = true;
      }
      canvas.drawPath(path, paint);
      if (!dots) return;
      for (var i = 0; i < series.length; i++) {
        final v = series[i];
        if (v == null) continue;
        canvas.drawCircle(
          Offset(x(i), y(v)),
          3.5,
          Paint()..color = v < 0 ? negative : color,
        );
      }
    }

    line(
      before,
      Paint()
        ..color = muted.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    line(
      after,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
      dots: true,
    );
  }

  @override
  bool shouldRepaint(_SaldoPainter old) =>
      old.before != before || old.after != after || old.color != color;
}

/// Savings in the first paying month × target, the reserve, and the price
/// in days of diário.
class _KeyFigures extends StatelessWidget {
  const _KeyFigures({required this.result});

  final WhatIfResult result;

  @override
  Widget build(BuildContext context) {
    final months = result.escolhida.meses;
    final paying = months.firstWhere(
      (m) => _num(m.pagaNoMes) > 0,
      orElse: () => months.isEmpty ? _emptyMonth : months.first,
    );
    final reserva = result.reserva;
    final reserveMonths = _num(reserva?.meses);

    final tiles = <Widget>[
      if (months.isNotEmpty)
        _Tile(
          icon: Icons.savings_outlined,
          label: 'Guarda em ${formatMonth(paying.month)}',
          value: _money(paying.guardaDepois),
          caption: 'meta ${result.metaPercent}%: ${_money(paying.meta)}',
          color: paying.ficaAbaixoDaMeta ? AppColors.saida : AppColors.surplus,
        ),
      if (reserva != null)
        _Tile(
          icon: Icons.shield_outlined,
          label: 'Reserva',
          value: reserva.meses == null
              ? _money(reserva.saldo)
              : '${reserveMonths.toStringAsFixed(1).replaceAll('.', ',')} m',
          caption: reserva.completa
              ? 'completa'
              : 'meta ${reserva.metaMeses} meses',
          color: reserva.completa ? AppColors.surplus : AppColors.metaAcima,
        ),
      if (result.diasDeDiario != null)
        _Tile(
          icon: Icons.calendar_today_outlined,
          label: 'Equivale a',
          value: '${result.diasDeDiario} dias',
          caption: 'do seu diário',
          color: AppColors.diario,
        ),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }

  static const _emptyMonth = WhatIfMonth(
    mes: '2000-01',
    pagaNoMes: '0',
    menorSaldoAntes: null,
    menorSaldoDepois: null,
    guardaAntes: '0',
    guardaDepois: '0',
    meta: '0',
    ficaAbaixoDaMeta: false,
    ficaNegativo: false,
  );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              caption,
              maxLines: 2,
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option, required this.best});

  final WhatIfOption option;
  final bool best;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        option.isCard ? Icons.credit_card : Icons.pix,
        color: option.isCard ? AppColors.cartao : AppColors.entrada,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              option.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: best ? FontWeight.w700 : null),
            ),
          ),
          if (best) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.star_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ],
        ],
      ),
      subtitle: Text(
        [
          option.parcelas > 1
              ? '${option.parcelas}x de ${_money(option.valorParcela)}'
              : _money(option.valorTotal),
          if (option.menorSaldo != null)
            'saldo mín. ${_money(option.menorSaldo)}',
        ].join(' · '),
      ),
      trailing: VerdictChip(option.verdict),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({required this.month, required this.metaPercent});

  final WhatIfMonth month;
  final String metaPercent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final paga = _num(month.pagaNoMes);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(formatMonth(month.month), style: theme.textTheme.titleSmall),
              const Spacer(),
              if (paga > 0) Text('paga ${formatCurrency(month.pagaNoMes)}'),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Guarda ${formatCurrency(month.guardaAntes)} → '
            '${formatCurrency(month.guardaDepois)} '
            '(meta $metaPercent%: ${formatCurrency(month.meta)})',
            style: theme.textTheme.bodySmall?.copyWith(
              color: month.ficaAbaixoDaMeta ? AppColors.saida : muted,
            ),
          ),
          if (month.menorSaldoDepois != null)
            Text(
              'Menor saldo: ${formatCurrency(month.menorSaldoDepois!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: month.ficaNegativo ? AppColors.saldoDarkRed : muted,
              ),
            ),
        ],
      ),
    );
  }
}
